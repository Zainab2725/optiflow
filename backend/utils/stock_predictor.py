import os
import json
from datetime import datetime, timedelta
from typing import Optional

# ─────────────────────────────────────────
# HELPER: Parse date strings safely
# ─────────────────────────────────────────
def parse_date(date_str: str) -> Optional[datetime]:
    if not date_str:
        return None
    formats = [
        "%Y-%m-%d",
        "%d-%m-%Y",
        "%m/%d/%Y",
        "%Y/%m/%d",
        "%d/%m/%Y"
    ]
    for fmt in formats:
        try:
            return datetime.strptime(str(date_str).strip(), fmt)
        except ValueError:
            continue
    return None


# ─────────────────────────────────────────
# HELPER: Calculate days since last update
# ─────────────────────────────────────────
def days_since_update(last_updated: str) -> float:
    parsed = parse_date(last_updated)
    if not parsed:
        return 3.0  # assume 3 days if unknown
    delta = datetime.utcnow() - parsed
    days = delta.total_seconds() / 86400
    return max(0.1, round(days, 2))


# ─────────────────────────────────────────
# CORE: Calculate dynamic daily usage rate
# from warehouse record alone
# ─────────────────────────────────────────
def calculate_dynamic_daily_usage(
    quantity: int,
    last_updated: str,
    sku: str = ""
) -> dict:
    days_old = days_since_update(last_updated)

    # Estimate how much was consumed since last update
    # Logic: assume stock started at quantity * 1.8 
    # (conservative stock refill assumption)
    # consumed = original - current
    estimated_original = quantity * 1.8
    estimated_consumed = estimated_original - quantity
    
    # Guard: if consumed is negative or zero use fallback
    if estimated_consumed <= 0:
        estimated_consumed = quantity * 0.3  # assume 30% consumed
    
    raw_daily = estimated_consumed / days_old

    # Apply realistic floor and ceiling
    # Floor: minimum 5 units/day (even slow moving items)
    # Ceiling: maximum 600 units/day (pharma reality check)
    base_daily = max(5.0, min(600.0, round(raw_daily, 1)))

    return {
        "base_daily_usage": base_daily,
        "days_since_update": round(days_old, 1),
        "estimated_original_stock": round(estimated_original),
        "estimated_consumed": round(estimated_consumed),
        "calculation_method": "dynamic_from_warehouse_data"
    }


# ─────────────────────────────────────────
# CORE: Complaint-based demand multiplier
# ─────────────────────────────────────────
def calculate_demand_multiplier(
    complaints_for_sku: int,
    complaint_trend: str,
    complaint_spike: bool
) -> dict:
    if complaints_for_sku >= 4:
        multiplier = 1.8
        signal = "CRITICAL SPIKE"
        explanation = f"{complaints_for_sku} complaints indicate severe shortage demand"
    elif complaints_for_sku >= 3:
        multiplier = 1.5
        signal = "HIGH DEMAND"
        explanation = f"{complaints_for_sku} complaints show strong unmet demand"
    elif complaints_for_sku >= 2:
        multiplier = 1.3
        signal = "ELEVATED"
        explanation = f"{complaints_for_sku} complaints show above-normal demand"
    elif complaints_for_sku == 1:
        multiplier = 1.1
        signal = "SLIGHTLY ELEVATED"
        explanation = "1 complaint registered, minor demand increase likely"
    else:
        multiplier = 1.0
        signal = "NORMAL"
        explanation = "No complaints, demand appears normal"

    # Extra boost if system-wide spike detected
    if complaint_spike and complaints_for_sku > 0:
        multiplier = round(multiplier * 1.15, 2)
        explanation += " (system-wide spike detected)"

    # Extra boost if trend is rising
    if complaint_trend == "rising":
        multiplier = round(multiplier * 1.1, 2)
        explanation += " (rising trend)"

    return {
        "multiplier": round(multiplier, 2),
        "demand_signal": signal,
        "explanation": explanation
    }


# ─────────────────────────────────────────
# CORE: Risk classification
# ─────────────────────────────────────────
def classify_risk(days_remaining: float) -> dict:
    if days_remaining <= 1:
        return {
            "risk_level": "CRITICAL",
            "action": "Emergency order required immediately",
            "urgency": "SAME DAY"
        }
    elif days_remaining <= 2:
        return {
            "risk_level": "CRITICAL",
            "action": "Place emergency order within 6 hours",
            "urgency": "TODAY"
        }
    elif days_remaining <= 4:
        return {
            "risk_level": "HIGH",
            "action": "Place urgent order within 24 hours",
            "urgency": "TOMORROW"
        }
    elif days_remaining <= 7:
        return {
            "risk_level": "MEDIUM",
            "action": "Schedule reorder within 3-4 days",
            "urgency": "THIS WEEK"
        }
    elif days_remaining <= 14:
        return {
            "risk_level": "LOW",
            "action": "Monitor and plan regular reorder",
            "urgency": "NEXT WEEK"
        }
    else:
        return {
            "risk_level": "SAFE",
            "action": "Stock sufficient, no action needed",
            "urgency": "NONE"
        }


# ─────────────────────────────────────────
# CORE: 7-day forecast per SKU
# ─────────────────────────────────────────
def build_weekly_forecast(
    current_quantity: int,
    adjusted_daily: float
) -> list:
    forecast = []
    running = float(current_quantity)
    
    for day in range(1, 8):
        running = max(0.0, running - adjusted_daily)
        date_str = (
            datetime.utcnow() + timedelta(days=day)
        ).strftime("%Y-%m-%d")
        
        if running <= 0:
            status = "DEPLETED"
        elif running < adjusted_daily:
            status = "CRITICAL"
        elif running < adjusted_daily * 3:
            status = "LOW"
        else:
            status = "OK"
        
        forecast.append({
            "day": day,
            "date": date_str,
            "projected_stock": round(running),
            "status": status
        })
    
    return forecast


# ─────────────────────────────────────────
# MAIN: Predict depletion for one SKU
# ─────────────────────────────────────────
def predict_single_sku(
    record: dict,
    complaints_for_sku: int,
    complaint_trend: str,
    complaint_spike: bool
) -> dict:
    sku = record.get("sku", "UNKNOWN")
    product_name = record.get("product_name", sku)
    last_updated = str(record.get("last_updated", ""))
    
    try:
        quantity = int(float(str(record.get("quantity", 0))))
    except (ValueError, TypeError):
        quantity = 0

    # Step 1: Calculate dynamic daily usage from warehouse data
    usage_calc = calculate_dynamic_daily_usage(quantity, last_updated, sku)
    base_daily = usage_calc["base_daily_usage"]

    # Step 2: Apply complaint-based demand multiplier
    demand = calculate_demand_multiplier(
        complaints_for_sku, complaint_trend, complaint_spike
    )
    multiplier = demand["multiplier"]
    adjusted_daily = round(base_daily * multiplier, 1)
    adjusted_daily = max(1.0, adjusted_daily)  # floor at 1

    # Step 3: Calculate days remaining
    days_remaining = round(quantity / adjusted_daily, 1) if adjusted_daily > 0 else 999

    # Step 4: Classify risk
    risk = classify_risk(days_remaining)

    # Step 5: Predict depletion date
    depletion_date = (
        datetime.utcnow() + timedelta(days=days_remaining)
    ).strftime("%Y-%m-%d")

    # Step 6: Build 7-day forecast
    forecast = build_weekly_forecast(quantity, adjusted_daily)

    # Step 7: Staleness flag
    days_old = usage_calc["days_since_update"]
    stale = days_old > 2

    return {
        "sku": sku,
        "product_name": product_name,
        "current_quantity": quantity,
        "last_updated": last_updated,
        "data_staleness_days": days_old,
        "data_is_stale": stale,
        "usage_calculation": usage_calc,
        "demand_analysis": demand,
        "base_daily_usage": base_daily,
        "adjusted_daily_usage": adjusted_daily,
        "days_remaining": days_remaining,
        "predicted_depletion_date": depletion_date,
        "risk_level": risk["risk_level"],
        "recommended_action": risk["action"],
        "urgency": risk["urgency"],
        "weekly_forecast": forecast,
        "predicted_at": datetime.utcnow().isoformat()
    }


# ─────────────────────────────────────────
# MASTER: Run predictions for all SKUs
# ─────────────────────────────────────────
def run_stock_predictions(
    warehouse_records: list,
    complaint_summary: dict
) -> dict:
    by_sku = complaint_summary.get("by_sku", {})
    last_24h = complaint_summary.get("last_24h", 0)
    complaint_spike = complaint_summary.get("complaint_spike", False)
    complaint_trend = "rising" if complaint_spike else "stable"

    predictions = []
    critical_skus = []
    high_risk_skus = []
    safe_skus = []

    for record in warehouse_records:
        sku = record.get("sku", "")
        if not sku:
            continue

        sku_complaints = by_sku.get(sku, 0)

        prediction = predict_single_sku(
            record=record,
            complaints_for_sku=sku_complaints,
            complaint_trend=complaint_trend,
            complaint_spike=complaint_spike
        )
        predictions.append(prediction)

        level = prediction["risk_level"]
        if level == "CRITICAL":
            critical_skus.append(sku)
        elif level == "HIGH":
            high_risk_skus.append(sku)
        elif level == "SAFE":
            safe_skus.append(sku)

    # Sort by days_remaining ascending (most urgent first)
    predictions.sort(key=lambda x: x["days_remaining"])

    overall_risk = "SAFE"
    if critical_skus:
        overall_risk = "CRITICAL"
    elif high_risk_skus:
        overall_risk = "HIGH"
    elif len(safe_skus) < len(predictions):
        overall_risk = "MEDIUM"

    return {
        "predictions": predictions,
        "summary": {
            "total_skus_analyzed": len(predictions),
            "critical_count": len(critical_skus),
            "high_risk_count": len(high_risk_skus),
            "safe_count": len(safe_skus),
            "critical_skus": critical_skus,
            "high_risk_skus": high_risk_skus,
            "overall_risk": overall_risk,
            "complaint_trend": complaint_trend,
            "complaint_spike": complaint_spike,
            "total_complaints_24h": last_24h
        },
        "predicted_at": datetime.utcnow().isoformat()
    }
