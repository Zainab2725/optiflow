import json
import os
import uuid
from datetime import datetime

ORGS_FILE = "backend/data/organizations.json"
STOCK_FILE = "backend/data/org_stock.json"
INCIDENTS_FILE = "backend/data/org_incidents.json"

def _load(path: str) -> list:
    os.makedirs(os.path.dirname(path), exist_ok=True)
    if not os.path.exists(path):
        return []
    with open(path, "r") as f:
        return json.load(f)

def _save(path: str, data: list):
    os.makedirs(os.path.dirname(path), exist_ok=True)
    with open(path, "w") as f:
        json.dump(data, f, indent=2)

# ── ORGANIZATIONS ──

def create_org(name: str, org_type: str) -> dict:
    orgs = _load(ORGS_FILE)
    org = {
        "org_id": f"org-{str(uuid.uuid4())[:8]}",
        "name": name,
        "org_type": org_type,
        "created_at": datetime.utcnow().isoformat(),
        "active": True
    }
    orgs.append(org)
    _save(ORGS_FILE, orgs)
    return org

def get_orgs() -> list:
    return _load(ORGS_FILE)

def get_org(org_id: str) -> dict:
    orgs = _load(ORGS_FILE)
    return next((o for o in orgs if o["org_id"] == org_id), None)

# ── STOCK PER ORG ──

def save_org_stock(record: dict) -> dict:
    stocks = _load(STOCK_FILE)
    record["id"] = str(uuid.uuid4())[:8]
    record["timestamp"] = datetime.utcnow().isoformat()
    
    # Check threshold
    qty = record.get("quantity", 0)
    threshold = record.get("min_threshold", 500)
    record["threshold_breached"] = qty < threshold
    record["status"] = "CRITICAL" if qty < threshold else "NORMAL"
    
    stocks.append(record)
    _save(STOCK_FILE, stocks)
    return record

def get_org_stock(org_id: str = None) -> list:
    stocks = _load(STOCK_FILE)
    if org_id:
        return [s for s in stocks if s.get("org_id") == org_id]
    return stocks

def get_stock_summary(org_id: str = None) -> dict:
    stocks = get_org_stock(org_id)
    critical = [s for s in stocks if s.get("status") == "CRITICAL"]
    by_zone = {}
    for s in stocks:
        zone = s.get("zone", "unknown")
        by_zone[zone] = by_zone.get(zone, 0) + 1
    return {
        "total_records": len(stocks),
        "critical_count": len(critical),
        "normal_count": len(stocks) - len(critical),
        "by_zone": by_zone,
        "critical_skus": [s.get("sku") for s in critical]
    }

# ── INCIDENTS PER ORG ──

def save_org_incident(record: dict) -> dict:
    incidents = _load(INCIDENTS_FILE)
    record["id"] = str(uuid.uuid4())[:8]
    record["timestamp"] = datetime.utcnow().isoformat()
    record["resolved"] = False
    
    # Tag risk level
    severity = record.get("severity", "low")
    if severity == "critical":
        record["risk_tag"] = "RED"
    elif severity == "high":
        record["risk_tag"] = "YELLOW"
    else:
        record["risk_tag"] = "GREEN"
    
    incidents.append(record)
    _save(INCIDENTS_FILE, incidents)
    return record

def get_org_incidents(org_id: str = None, 
                       zone: str = None) -> list:
    incidents = _load(INCIDENTS_FILE)
    if org_id:
        incidents = [i for i in incidents 
                     if i.get("org_id") == org_id]
    if zone:
        incidents = [i for i in incidents 
                     if i.get("location_zone") == zone]
    incidents.sort(
        key=lambda x: x.get("timestamp", ""), 
        reverse=True
    )
    return incidents

def get_zone_risk_map() -> dict:
    incidents = _load(INCIDENTS_FILE)
    stocks = _load(STOCK_FILE)
    
    KARACHI_ZONES = [
        "Saddar", "Clifton", "SITE", "Korangi", 
        "Malir", "Faisal", "Gulshan", "PECHS",
        "North Nazimabad", "Orangi", "Lyari", "Defence"
    ]
    
    risk_map = {}
    for zone in KARACHI_ZONES:
        zone_incidents = [
            i for i in incidents 
            if i.get("location_zone") == zone 
            and not i.get("resolved", False)
        ]
        critical_count = len([
            i for i in zone_incidents 
            if i.get("severity") == "critical"
        ])
        total_count = len(zone_incidents)
        
        if critical_count >= 2 or total_count >= 3:
            risk = "RED"
        elif total_count >= 1:
            risk = "YELLOW"
        else:
            risk = "GREEN"
        
        risk_map[zone] = {
            "risk": risk,
            "active_incidents": total_count,
            "critical_incidents": critical_count
        }
    
    return risk_map

# ── CONTRADICTION DETECTION ──

def detect_org_contradictions() -> list:
    stocks = _load(STOCK_FILE)
    incidents = _load(INCIDENTS_FILE)
    contradictions = []
    
    for stock in stocks:
        sku = stock.get("sku")
        qty = stock.get("quantity", 0)
        zone = stock.get("zone")
        
        if qty <= 5000:
            continue
        
        sku_incidents = [
            i for i in incidents
            if i.get("sku") == sku
            and i.get("severity") in ["critical", "high"]
            and not i.get("resolved", False)
        ]
        
        if len(sku_incidents) >= 3:
            contradictions.append({
                "sku": sku,
                "item_name": stock.get("item_name"),
                "depot": stock.get("depot_name"),
                "zone": zone,
                "ledger_quantity": qty,
                "ground_reports": len(sku_incidents),
                "anomaly": "DISTRIBUTION_GAP",
                "explanation": (
                    f"Ledger shows {qty} units at {zone} depot "
                    f"but {len(sku_incidents)} critical ground "
                    f"reports indicate zero physical availability. "
                    f"Distribution anomaly detected."
                ),
                "detected_at": datetime.utcnow().isoformat()
            })
    
    return contradictions
