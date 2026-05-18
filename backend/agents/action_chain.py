import json
import os
from datetime import datetime

BUDGET_PKR = 5000000

def validate_stock(alerts: list, inventory: list) -> dict:
    critical = [a for a in alerts if a.get("risk_level") == "CRITICAL"]
    affected_skus = [a.get("sku") for a in critical]
    affected_records = [r for r in inventory if r.get("sku") in affected_skus]
    return {
        "step": 1,
        "action": "validate_stock",
        "status": "completed",
        "affected_skus": affected_skus,
        "warehouse_records": affected_records,
        "verdict": "Stock validation overridden by complaint signal",
        "timestamp": datetime.utcnow().isoformat()
    }

def notify_procurement(alerts: list, pkr_rate: float = 279.0) -> dict:
    critical = [a for a in alerts if a.get("risk_level") == "CRITICAL"]
    notifications = []
    for alert in critical:
        notifications.append({
            "to": "crisis@optiflow.pk",
            "subject": f"URBAN CRISIS ALERT: {alert.get('item_name')} - {alert.get('location')}",
            "body": (
                f"Critical shortage detected for {alert.get('item_name')} "
                f"in {alert.get('location')}. "
                f"Reason: {alert.get('reason')}. "
                f"Immediate action required. Budget available: PKR {BUDGET_PKR:,}"
            ),
            "priority": "HIGH",
            "sent_at": datetime.utcnow().isoformat()
        })
    return {
        "step": 2,
        "action": "notify_procurement",
        "status": "completed",
        "notifications_sent": len(notifications),
        "notifications": notifications,
        "timestamp": datetime.utcnow().isoformat()
    }

def simulate_emergency_order(alerts: list, pkr_rate: float = 279.0) -> dict:
    critical = [a for a in alerts if a.get("risk_level") == "CRITICAL"]
    orders = []
    remaining_budget = BUDGET_PKR

    for alert in critical:
        unit_cost_pkr = 450
        max_units = remaining_budget // unit_cost_pkr
        if max_units <= 0:
            orders.append({
                "sku": alert.get("sku"),
                "status": "REJECTED",
                "reason": f"Budget exhausted. Remaining: PKR {remaining_budget:,}"
            })
            continue
        order_qty = min(max_units, 150)
        order_cost = order_qty * unit_cost_pkr
        remaining_budget -= order_cost
        orders.append({
            "sku": alert.get("sku"),
            "item_name": alert.get("item_name"),
            "order_quantity": order_qty,
            "unit_cost_pkr": unit_cost_pkr,
            "total_cost_pkr": order_cost,
            "supplier": "NDMA Emergency Supply Chain",
            "estimated_delivery": "2-3 business days",
            "status": "SIMULATED_ORDER_PLACED",
            "po_number": f"EMG-{datetime.utcnow().strftime('%Y%m%d%H%M')}-{alert.get('sku')}"
        })

    return {
        "step": 3,
        "action": "simulate_emergency_order",
        "status": "completed",
        "budget_total_pkr": BUDGET_PKR,
        "budget_used_pkr": BUDGET_PKR - remaining_budget,
        "budget_remaining_pkr": remaining_budget,
        "orders": orders,
        "constraint_check": "PASSED" if remaining_budget >= 0 else "EXCEEDED",
        "timestamp": datetime.utcnow().isoformat()
    }

def update_customer_notifications(alerts: list, complaints: list) -> dict:
    critical_skus = [a.get("sku") for a in alerts if a.get("risk_level") == "CRITICAL"]
    affected_complaints = [c for c in complaints if c.get("sku") in critical_skus]
    notifications = []
    for complaint in affected_complaints:
        notifications.append({
            "customer": complaint.get("customer_name", "Valued Customer"),
            "location": complaint.get("location", "Karachi"),
            "sku": complaint.get("sku"),
            "message": (
                f"Dear {complaint.get('customer_name', 'Customer')}, "
                f"we are aware of the shortage of "
                f"{complaint.get('product_name', 'your requested medicine')} "
                f"in {complaint.get('location', 'your area')}. "
                f"An emergency order has been placed. "
                f"Expected availability: 2-3 business days. "
                f"We apologize for the inconvenience."
            ),
            "channel": "SMS",
            "status": "DRAFTED"
        })
    return {
        "step": 4,
        "action": "update_customer_notifications",
        "status": "completed",
        "customers_notified": len(notifications),
        "notifications": notifications,
        "timestamp": datetime.utcnow().isoformat()
    }

def schedule_monitoring(alerts: list) -> dict:
    critical = [a for a in alerts if a.get("risk_level") == "CRITICAL"]
    return {
        "step": 5,
        "action": "schedule_monitoring",
        "status": "completed",
        "monitoring_tasks": [
            {
                "sku": alert.get("sku"),
                "check_interval_minutes": 60,
                "alert_threshold": "2+ new complaints",
                "escalation": "Auto-notify senior procurement",
                "duration_hours": 24,
                "next_check": datetime.utcnow().isoformat()
            }
            for alert in critical
        ],
        "total_tasks_scheduled": len(critical),
        "timestamp": datetime.utcnow().isoformat()
    }

def run_action_chain(analysis_result: dict, 
                     inventory: list, 
                     complaints: list,
                     pkr_rate: float = 279.0) -> dict:
    alerts = analysis_result.get("alerts", [])
    
    chain_results = []
    failed_step = None

    try:
        step1 = validate_stock(alerts, inventory)
        chain_results.append(step1)
    except Exception as e:
        failed_step = {"step": 1, "error": str(e), "status": "FAILED"}
        chain_results.append(failed_step)

    try:
        step2 = notify_procurement(alerts, pkr_rate)
        chain_results.append(step2)
    except Exception as e:
        chain_results.append({"step": 2, "error": str(e), "status": "FAILED"})

    try:
        step3 = simulate_emergency_order(alerts, pkr_rate)
        chain_results.append(step3)
    except Exception as e:
        chain_results.append({"step": 3, "error": str(e), "status": "FAILED"})

    try:
        step4 = update_customer_notifications(alerts, complaints)
        chain_results.append(step4)
    except Exception as e:
        chain_results.append({"step": 4, "error": str(e), "status": "FAILED"})

    try:
        step5 = schedule_monitoring(alerts)
        chain_results.append(step5)
    except Exception as e:
        chain_results.append({"step": 5, "error": str(e), "status": "FAILED"})

    critical_count = len([a for a in alerts if a.get("risk_level") == "CRITICAL"])
    
    return {
        "action_chain_id": datetime.utcnow().strftime("%Y%m%d_%H%M%S"),
        "total_steps": 5,
        "completed_steps": len([s for s in chain_results if s.get("status") == "completed"]),
        "chain_results": chain_results,
        "before_state": {
            "stockout_risk": "HIGH" if critical_count > 0 else "LOW",
            "supplier_status": "unverified",
            "customer_notifications": 0,
            "open_complaints": len(complaints)
        },
        "after_state": {
            "stockout_risk": "REDUCED" if critical_count > 0 else "LOW",
            "supplier_status": "emergency_order_placed",
            "customer_notifications": len(complaints),
            "open_complaints": len(complaints),
            "emergency_orders": critical_count
        },
        "chain_timestamp": datetime.utcnow().isoformat()
    }
