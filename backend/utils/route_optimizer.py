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
async def optimize_route(
    weather_data: dict,
    news_headlines: list,
    origin: str = "Hyderabad, Pakistan",
    destination: str = "Karachi, Pakistan",
    org_id: str = "org-demo"
) -> dict:
    org_id = org_id or "org-demo"
    weather_risks = extract_weather_risks(weather_data)
    news_risks = extract_news_risks(news_headlines)

    # 1. Detect if this is local Karachi warehouse routing
    KARACHI_ZONES = ["site", "clifton", "saddar", "malir", "korangi", "lyari", "orangi", "defence", "gulshan", "north nazimabad", "pechs", "faisal"]
    is_local = False
    for z in KARACHI_ZONES:
        if z in origin.lower() or z in destination.lower():
            is_local = True
            break

    if is_local:
        # Load local incidents from this organization to check for transit blockages!
        from utils.org_store import get_org_incidents
        incidents = get_org_incidents(org_id)
        
        # Determine if transit zones have any active incidents
        saddar_incidents = [i for i in incidents if "saddar" in i.get("location_zone", "").lower() and not i.get("resolved", False)]
        site_incidents = [i for i in incidents if "site" in i.get("location_zone", "").lower() and not i.get("resolved", False)]
        clifton_incidents = [i for i in incidents if "clifton" in i.get("location_zone", "").lower() and not i.get("resolved", False)]
        korangi_incidents = [i for i in incidents if "korangi" in i.get("location_zone", "").lower() and not i.get("resolved", False)]

        # Dynamically calculate distance based on geographical coordinates of the selected zones
        ZONE_COORDS = {
            "site": (24.90, 67.01),
            "clifton": (24.81, 67.03),
            "saddar": (24.86, 67.02),
            "malir": (24.90, 67.19),
            "korangi": (24.83, 67.12),
            "lyari": (24.87, 66.99),
            "orangi": (24.95, 66.96),
            "defence": (24.82, 67.07),
            "gulshan": (24.92, 67.09),
            "north nazimabad": (24.94, 67.03),
            "pechs": (24.87, 67.07),
            "faisal": (24.89, 67.14),
        }

        def get_coord(name: str):
            name_l = name.lower()
            for k, v in ZONE_COORDS.items():
                if k in name_l:
                    return v
            return (24.86, 67.02) # Default Saddar

        p1 = get_coord(origin)
        p2 = get_coord(destination)
        
        # Approximate L2 distance
        d_lat = (p1[0] - p2[0]) * 111.0
        d_lng = (p1[1] - p2[1]) * 100.0
        base_dist = round((d_lat**2 + d_lng**2)**0.5, 1)
        if base_dist < 3.0:
            base_dist = 6.8 # Default minimum city distance for nearby zones

        # Dynamic travel times based on distance
        direct_base_time = int(base_dist * 1.8 + 4)
        bypass_base_dist = round(base_dist + 3.5, 1)
        bypass_base_time = max(8, int(bypass_base_dist * 1.2 + 2))
        alt_base_dist = round(base_dist + 6.2, 1)
        alt_base_time = int(alt_base_dist * 1.5 + 5)

        # Path 1: Central City Arterial Route (Direct Path - passes through Saddar and central corridors)
        direct_reasons = []
        direct_warnings = []
        direct_score = 100
        direct_delay = 0
        
        if saddar_incidents:
            direct_score -= 40
            direct_delay += 35
            direct_reasons.append(f"Saddar blockage: {saddar_incidents[0].get('message', 'Road blockage')}")
            direct_warnings.append("Saddar central corridor is heavily congested/blocked.")
        if clifton_incidents:
            direct_score -= 20
            direct_delay += 15
            direct_reasons.append(f"Clifton traffic warning: {clifton_incidents[0].get('message', 'Water accumulation')}")
            
        # Path 2: Lyari Expressway Fast Bypass
        bypass_reasons = []
        bypass_warnings = []
        bypass_score = 95
        bypass_delay = 0
        
        if site_incidents and "site" in destination.lower():
            bypass_score -= 15
            bypass_delay += 10
            bypass_reasons.append(f"SITE depot advisory: {site_incidents[0].get('message', 'Grid issue')}")
            
        # Path 3: Coastal Ring Road
        alt_reasons = []
        alt_warnings = []
        alt_score = 85
        alt_delay = 0
        if korangi_incidents and ("korangi" in origin.lower() or "korangi" in destination.lower()):
            alt_score -= 25
            alt_delay += 20
            alt_reasons.append(f"Korangi traffic advisory: {korangi_incidents[0].get('message', 'Heavy flow')}")

        rec_direct = "RECOMMENDED" if direct_score >= 80 else ("PROCEED WITH CAUTION" if direct_score >= 60 else "AVOID")
        rec_bypass = "RECOMMENDED" if bypass_score >= 80 else ("PROCEED WITH CAUTION" if bypass_score >= 60 else "AVOID")
        rec_alt = "RECOMMENDED" if alt_score >= 80 else ("PROCEED WITH CAUTION" if alt_score >= 60 else "AVOID")

        routes_list = [
            {
                "route_key": "DIRECT",
                "route_name": f"City Arterial Corridor (via Saddar & M.A. Jinnah Rd)",
                "distance_km": base_dist,
                "normal_time_min": direct_base_time,
                "estimated_time_min": direct_base_time + direct_delay,
                "delay_added_min": direct_delay,
                "score": max(0, direct_score),
                "recommendation": rec_direct,
                "color": "green" if direct_score >= 80 else ("yellow" if direct_score >= 60 else "red"),
                "reasons": direct_reasons or [f"Standard direct city corridor from {origin} to {destination} is clear."],
                "warnings": direct_warnings,
                "road_type": "city_arterial",
                "description": f"Standard direct transit between {origin} and {destination} hubs."
            },
            {
                "route_key": "BYPASS",
                "route_name": "Lyari Expressway Fast Bypass",
                "distance_km": bypass_base_dist,
                "normal_time_min": bypass_base_time,
                "estimated_time_min": bypass_base_time + bypass_delay,
                "delay_added_min": bypass_delay,
                "score": max(0, bypass_score),
                "recommendation": rec_bypass,
                "color": "green" if bypass_score >= 80 else ("yellow" if bypass_score >= 60 else "red"),
                "reasons": bypass_reasons or ["Express corridor completely bypassing central Saddar bottlenecks."],
                "warnings": bypass_warnings,
                "road_type": "expressway",
                "description": "High-speed toll expressway bypassing city center."
            },
            {
                "route_key": "ALTERNATE",
                "route_name": "Coastal Ring Road (via Clifton Beach & Korangi Rd)",
                "distance_km": alt_base_dist,
                "normal_time_min": alt_base_time,
                "estimated_time_min": alt_base_time + alt_delay,
                "delay_added_min": alt_delay,
                "score": max(0, alt_score),
                "recommendation": rec_alt,
                "color": "green" if alt_score >= 80 else ("yellow" if alt_score >= 60 else "red"),
                "reasons": alt_reasons or ["Coastal link with smooth transit outside central hubs."],
                "warnings": alt_warnings,
                "road_type": "coastal_arterial",
                "description": "Outer ring road recommended when central blockages are high."
            }
        ]

        routes_list.sort(key=lambda x: x["score"], reverse=True)
        best = routes_list[0]
        worst = routes_list[-1]

        hold_decision = {
            "hold_shipment": best["score"] < 40,
            "decision": "HOLD" if best["score"] < 40 else ("PROCEED WITH CAUTION" if best["score"] < 75 else "CLEAR TO PROCEED"),
            "reason": (
                f"Severe local disruptions in Karachi transit corridors. Best route ({best['route_name']}) scores only {best['score']}/100."
                if best["score"] < 40 else
                f"Safe to proceed via {best['route_name']} (safety score {best['score']}/100) bypassing central congestion."
            ),
            "recheck_in_hours": 1
        }

        summary_parts = []
        if saddar_incidents:
            summary_parts.append("Saddar blockage active")
        if site_incidents:
            summary_parts.append("SITE supply chain risk active")
        if not summary_parts:
            summary_parts.append("All Karachi local corridors fully operational")

        decision_summary = (
            f"Recommended Detour: {best['route_name']} "
            f"(ETA {best['estimated_time_min']} mins, Safety Score {best['score']}/100). "
            f"Bypassing active bottlenecks: " + ", ".join(summary_parts)
        )

        return {
            "recommended_route": best,
            "all_routes_ranked": routes_list,
            "worst_route": {
                "route_key": worst["route_key"],
                "route_name": worst["route_name"],
                "score": worst["score"],
                "avoid_reason": worst["reasons"][0] if worst["reasons"] else "Slower alternative transit route"
            },
            "hold_decision": hold_decision,
            "risk_signals": {
                "weather": weather_risks,
                "news": news_risks,
                "live_traffic": {"status": "ok", "traffic": "nominal"}
            },
            "decision_summary": decision_summary,
            "origin": origin,
            "destination": destination,
            "optimized_at": datetime.utcnow().isoformat()
        }

    # 2. Fallback: Karachi-Hyderabad primary regional routes
    live_traffic = await get_live_traffic(origin, destination)
    scored_routes = []
    for route_key in ROUTES:
        scored = score_route(route_key, weather_risks, news_risks, live_traffic)
        scored_routes.append(scored)

    scored_routes.sort(key=lambda x: x["score"], reverse=True)
    best = scored_routes[0]
    worst = scored_routes[-1]

    hold_decision = make_hold_decision(
        best_score=best["score"],
        best_route_name=best["route_name"],
        weather_severity=weather_risks["severity"]
    )

    summary_parts = []
    if news_risks["m9_risk"]:
        summary_parts.append("M9 disruption detected in news")
    if news_risks["n55_risk"]:
        summary_parts.append("N-55 congestion detected in news")
    if weather_risks["severity"] != "CLEAR":
        summary_parts.append(f"Weather is {weather_risks['severity']} ({weather_risks['condition']})")
    if not summary_parts:
        summary_parts.append("All routes clear, no disruptions detected")

    decision_summary = (
        f"Recommended: {best['route_name']} "
        f"(score {best['score']}/100, ETA {best['estimated_time_min']} min). "
        + " | ".join(summary_parts)
    )

    return {
        "recommended_route": best,
        "all_routes_ranked": scored_routes,
        "worst_route": {
            "route_key": worst["route_key"],
            "route_name": worst["route_name"],
            "score": worst["score"],
            "avoid_reason": worst["reasons"][0] if worst["reasons"] else "Lowest score among available routes"
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

