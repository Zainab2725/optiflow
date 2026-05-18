import httpx
import os
from datetime import datetime
from typing import Optional

GOOGLE_MAPS_KEY = os.getenv("GOOGLE_MAPS_API_KEY", "")

# ─────────────────────────────────────────
# PAKISTAN ROUTES DATABASE
# These are real fixed roads - correct to hardcode
# What is NOT hardcoded: scores, delays, decisions
# ─────────────────────────────────────────
ROUTES = {
    "M9": {
        "name": "M9 Motorway (Karachi-Hyderabad)",
        "distance_km": 136,
        "normal_time_min": 90,
        "road_type": "motorway",
        "heavy_vehicle_allowed": True,
        "flood_prone": True,
        "description": "Fastest route, modern motorway, flood risk in rain"
    },
    "N55": {
        "name": "N-55 Superhighway",
        "distance_km": 148,
        "normal_time_min": 110,
        "road_type": "national_highway",
        "heavy_vehicle_allowed": True,
        "flood_prone": False,
        "description": "Alternate route, older road, handles diverted traffic"
    },
    "N25": {
        "name": "N-25 via Bela (Coastal)",
        "distance_km": 195,
        "normal_time_min": 160,
        "road_type": "national_highway",
        "heavy_vehicle_allowed": True,
        "flood_prone": False,
        "description": "Longest route, safest in bad weather, last resort"
    }
}

# ─────────────────────────────────────────
# HELPER: Extract risk signals from news
# Returns dict of detected risks per route
# ─────────────────────────────────────────
def extract_news_risks(news_headlines: list) -> dict:
    news_text = " ".join(news_headlines).lower()

    M9_KEYWORDS = [
        "m9", "m-9", "motorway", "karachi hyderabad motorway",
        "hyderabad karachi motorway", "motorway closed",
        "motorway blocked", "motorway flooded", "motorway damaged",
        "nha closed", "national highway authority closed"
    ]

    N55_KEYWORDS = [
        "superhighway", "n-55", "n55", "super highway",
        "old national highway", "traffic karachi highway",
        "congestion superhighway", "superhighway blocked"
    ]

    GENERAL_RISK_KEYWORDS = [
        "road closed", "highway blocked", "flood", "landslide",
        "accident karachi", "road damage", "bridge closed",
        "transport strike", "dharna", "protest karachi road"
    ]

    m9_risk = any(kw in news_text for kw in M9_KEYWORDS)
    n55_risk = any(kw in news_text for kw in N55_KEYWORDS)
    general_risk = any(kw in news_text for kw in GENERAL_RISK_KEYWORDS)

    matched_m9 = [kw for kw in M9_KEYWORDS if kw in news_text]
    matched_n55 = [kw for kw in N55_KEYWORDS if kw in news_text]
    matched_general = [kw for kw in GENERAL_RISK_KEYWORDS if kw in news_text]

    return {
        "m9_risk": m9_risk,
        "n55_risk": n55_risk,
        "general_risk": general_risk,
        "matched_keywords": {
            "m9": matched_m9,
            "n55": matched_n55,
            "general": matched_general
        }
    }


# ─────────────────────────────────────────
# HELPER: Extract risk signals from weather
# Returns structured weather risk assessment
# ─────────────────────────────────────────
def extract_weather_risks(weather_data: dict) -> dict:
    condition = weather_data.get("condition", "Clear")
    rain_mm = float(weather_data.get("rain_mm", 0) or 0)
    temp_c = weather_data.get("temp_c", 30)
    logistics_risk = weather_data.get("logistics_risk", "LOW")
    description = weather_data.get("description", "")

    HIGH_RISK_CONDITIONS = [
        "Thunderstorm", "Tornado", "Hurricane", "Squall"
    ]
    MEDIUM_RISK_CONDITIONS = [
        "Rain", "Drizzle", "Shower", "Mist", "Fog", "Haze"
    ]

    if condition in HIGH_RISK_CONDITIONS or rain_mm > 10:
        weather_severity = "SEVERE"
        m9_penalty = 50
        n55_penalty = 20
        n25_penalty = 10
        delay_m9 = 120
        delay_n55 = 40
        delay_n25 = 15
    elif condition in MEDIUM_RISK_CONDITIONS or rain_mm > 3:
        weather_severity = "MODERATE"
        m9_penalty = 25
        n55_penalty = 10
        n25_penalty = 5
        delay_m9 = 45
        delay_n55 = 20
        delay_n25 = 10
    elif logistics_risk == "HIGH":
        weather_severity = "ELEVATED"
        m9_penalty = 15
        n55_penalty = 5
        n25_penalty = 0
        delay_m9 = 30
        delay_n55 = 10
        delay_n25 = 0
    else:
        weather_severity = "CLEAR"
        m9_penalty = 0
        n55_penalty = 0
        n25_penalty = 0
        delay_m9 = 0
        delay_n55 = 0
        delay_n25 = 0

    return {
        "condition": condition,
        "rain_mm": rain_mm,
        "severity": weather_severity,
        "logistics_risk": logistics_risk,
        "penalties": {
            "M9": m9_penalty,
            "N55": n55_penalty,
            "N25": n25_penalty
        },
        "delays": {
            "M9": delay_m9,
            "N55": delay_n55,
            "N25": delay_n25
        }
    }


# ─────────────────────────────────────────
# CORE: Score a single route dynamically
# Score starts at 100, penalties reduce it
# All penalties come from live signals only
# ─────────────────────────────────────────
def score_route(
    route_key: str,
    weather_risks: dict,
    news_risks: dict,
    live_traffic: dict
) -> dict:
    route = ROUTES[route_key]
    score = 100
    delay_minutes = 0
    reasons = []
    warnings = []

    # --- Weather penalties (from live weather API) ---
    weather_penalty = weather_risks["penalties"].get(route_key, 0)
    weather_delay = weather_risks["delays"].get(route_key, 0)

    if weather_penalty > 0:
        score -= weather_penalty
        delay_minutes += weather_delay
        reasons.append(
            f"Weather: {weather_risks['condition']} "
            f"({weather_risks['severity']}) "
            f"adds {weather_delay} min delay on {route_key}"
        )

    # Extra flood penalty for M9 specifically
    if route_key == "M9" and route["flood_prone"]:
        if weather_risks["severity"] in ["MODERATE", "SEVERE"]:
            score -= 15
            delay_minutes += 20
            warnings.append("M9 is flood-prone - extra caution in rain")

    # --- News penalties (from live news/RSS) ---
    if route_key == "M9" and news_risks["m9_risk"]:
        score -= 35
        delay_minutes += 90
        matched = news_risks["matched_keywords"]["m9"]
        reasons.append(
            f"News signals M9 disruption "
            f"(keywords: {', '.join(matched[:3])})"
        )

    if route_key == "N55" and news_risks["n55_risk"]:
        score -= 20
        delay_minutes += 30
        matched = news_risks["matched_keywords"]["n55"]
        reasons.append(
            f"News signals N-55 congestion "
            f"(keywords: {', '.join(matched[:3])})"
        )

    if news_risks["general_risk"]:
        score -= 10
        delay_minutes += 15
        warnings.append("General road disruption signals detected in news")

    # --- Live traffic adjustment (if Google Maps available) ---
    if live_traffic.get("status") == "ok" and route_key == "M9":
        traffic_duration = live_traffic.get("duration_traffic", "")
        normal_duration = live_traffic.get("duration_normal", "")
        if traffic_duration and normal_duration and traffic_duration != normal_duration:
            score -= 10
            delay_minutes += 15
            reasons.append(
                f"Live traffic: normal {normal_duration}, "
                f"with traffic {traffic_duration}"
            )

    # Final score floor
    score = max(0, score)

    estimated_time = route["normal_time_min"] + delay_minutes

    if score >= 80:
        recommendation = "RECOMMENDED"
        color = "green"
    elif score >= 60:
        recommendation = "PROCEED WITH CAUTION"
        color = "yellow"
    elif score >= 40:
        recommendation = "AVOID IF POSSIBLE"
        color = "orange"
    else:
        recommendation = "AVOID"
        color = "red"

    return {
        "route_key": route_key,
        "route_name": route["name"],
        "distance_km": route["distance_km"],
        "normal_time_min": route["normal_time_min"],
        "estimated_time_min": estimated_time,
        "delay_added_min": delay_minutes,
        "score": score,
        "recommendation": recommendation,
        "color": color,
        "reasons": reasons,
        "warnings": warnings,
        "road_type": route["road_type"],
        "description": route["description"]
    }


# ─────────────────────────────────────────
# HELPER: Get live traffic from Google Maps
# Graceful fallback if no API key
# ─────────────────────────────────────────
async def get_live_traffic(
    origin: str,
    destination: str
) -> dict:
    if not GOOGLE_MAPS_KEY:
        return {
            "status": "no_api_key",
            "note": "Add GOOGLE_MAPS_API_KEY to .env for live traffic",
            "traffic": "unavailable"
        }

    url = "https://maps.googleapis.com/maps/api/directions/json"
    params = {
        "origin": origin,
        "destination": destination,
        "key": GOOGLE_MAPS_KEY,
        "departure_time": "now",
        "traffic_model": "best_guess"
    }

    try:
        async with httpx.AsyncClient(timeout=10) as client:
            r = await client.get(url, params=params)
        data = r.json()

        if data.get("status") == "OK":
            leg = data["routes"][0]["legs"][0]
            return {
                "status": "ok",
                "distance": leg["distance"]["text"],
                "duration_normal": leg["duration"]["text"],
                "duration_traffic": leg.get(
                    "duration_in_traffic", {}
                ).get("text", "unknown"),
                "start_address": leg.get("start_address", origin),
                "end_address": leg.get("end_address", destination),
                "traffic": "live"
            }

        return {
            "status": data.get("status", "unknown"),
            "traffic": "unavailable",
            "note": "Google Maps returned non-OK status"
        }

    except Exception as e:
        return {
            "status": "error",
            "error": str(e),
            "traffic": "unavailable"
        }


# ─────────────────────────────────────────
# HELPER: Hold shipment decision
# Based on best available route score
# ─────────────────────────────────────────
def make_hold_decision(
    best_score: int,
    best_route_name: str,
    weather_severity: str
) -> dict:
    if best_score < 35:
        return {
            "hold_shipment": True,
            "decision": "HOLD",
            "reason": (
                f"All routes are currently high risk. "
                f"Best route ({best_route_name}) scores only "
                f"{best_score}/100. "
                f"Weather severity: {weather_severity}. "
                f"Recommend holding shipment at origin depot. "
                f"Re-evaluate in 2 hours."
            ),
            "recheck_in_hours": 2
        }
    elif best_score < 55:
        return {
            "hold_shipment": False,
            "decision": "PROCEED WITH CAUTION",
            "reason": (
                f"Conditions are marginal. "
                f"Proceed on {best_route_name} (score: {best_score}/100) "
                f"with reduced speed and regular driver check-ins. "
                f"Monitor weather updates closely."
            ),
            "recheck_in_hours": 1
        }
    else:
        return {
            "hold_shipment": False,
            "decision": "CLEAR TO PROCEED",
            "reason": (
                f"Route conditions are acceptable. "
                f"{best_route_name} is recommended "
                f"(score: {best_score}/100). "
                f"Normal delivery timeline expected."
            ),
            "recheck_in_hours": 4
        }


# ─────────────────────────────────────────
# MASTER: Run full route optimization
# ─────────────────────────────────────────
async def optimize_route(
    weather_data: dict,
    news_headlines: list,
    origin: str = "Hyderabad, Pakistan",
    destination: str = "Karachi, Pakistan"
) -> dict:

    # Step 1: Extract risk signals from live sources
    weather_risks = extract_weather_risks(weather_data)
    news_risks = extract_news_risks(news_headlines)

    # Step 2: Get live traffic if Google Maps key available
    live_traffic = await get_live_traffic(origin, destination)

    # Step 3: Score all routes dynamically
    scored_routes = []
    for route_key in ROUTES:
        scored = score_route(route_key, weather_risks, news_risks, live_traffic)
        scored_routes.append(scored)

    # Step 4: Rank routes by score descending
    scored_routes.sort(key=lambda x: x["score"], reverse=True)

    best = scored_routes[0]
    worst = scored_routes[-1]

    # Step 5: Make hold/proceed decision
    hold_decision = make_hold_decision(
        best_score=best["score"],
        best_route_name=best["route_name"],
        weather_severity=weather_risks["severity"]
    )

    # Step 6: Build human-readable summary
    summary_parts = []
    if news_risks["m9_risk"]:
        summary_parts.append("M9 disruption detected in news")
    if news_risks["n55_risk"]:
        summary_parts.append("N-55 congestion detected in news")
    if weather_risks["severity"] != "CLEAR":
        summary_parts.append(
            f"Weather is {weather_risks['severity']} "
            f"({weather_risks['condition']})"
        )
    if not summary_parts:
        summary_parts.append("All routes clear, no disruptions detected")

    decision_summary = (
        f"Recommended: {best['route_name']} "
        f"(score {best['score']}/100, "
        f"ETA {best['estimated_time_min']} min). "
        + " | ".join(summary_parts)
    )

    return {
        "recommended_route": best,
        "all_routes_ranked": scored_routes,
        "worst_route": {
            "route_key": worst["route_key"],
            "route_name": worst["route_name"],
            "score": worst["score"],
            "avoid_reason": (
                worst["reasons"][0] if worst["reasons"]
                else "Lowest score among available routes"
            )
        },
        "hold_decision": hold_decision,
        "risk_signals": {
            "weather": weather_risks,
            "news": news_risks,
            "live_traffic": live_traffic
        },
        "decision_summary": decision_summary,
        "origin": origin,
        "destination": destination,
        "optimized_at": datetime.utcnow().isoformat()
    }
