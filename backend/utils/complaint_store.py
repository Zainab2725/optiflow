import json
import os
import uuid
from datetime import datetime, timedelta

COMPLAINTS_FILE = "backend/data/complaints.json"

def _load():
    if not os.path.exists(COMPLAINTS_FILE):
        return []
    with open(COMPLAINTS_FILE, "r") as f:
        return json.load(f)

def _save(data):
    os.makedirs(os.path.dirname(COMPLAINTS_FILE), exist_ok=True)
    with open(COMPLAINTS_FILE, "w") as f:
        json.dump(data, f, indent=2)

def save_complaint(complaint: dict) -> dict:
    complaints = _load()
    complaint["id"] = str(uuid.uuid4())[:8]
    complaint["timestamp"] = datetime.utcnow().isoformat()
    complaint["status"] = "open"
    complaints.append(complaint)
    _save(complaints)
    return complaint

def get_complaints(sku: str = None, limit: int = 20) -> list:
    complaints = _load()
    if sku:
        complaints = [c for c in complaints if c.get("sku") == sku]
    complaints.sort(key=lambda x: x.get("timestamp", ""), reverse=True)
    return complaints[:limit]

def get_complaint_summary() -> dict:
    complaints = _load()
    now = datetime.utcnow()
    cutoff = (now - timedelta(hours=24)).isoformat()
    last_24h = [c for c in complaints if c.get("timestamp", "") > cutoff]
    by_sku = {}
    for c in complaints:
        sku = c.get("sku", "unknown")
        by_sku[sku] = by_sku.get(sku, 0) + 1
    by_severity = {"high": 0, "medium": 0, "low": 0}
    for c in complaints:
        sev = c.get("severity", "low")
        by_severity[sev] = by_severity.get(sev, 0) + 1
    return {
        "total": len(complaints),
        "last_24h": len(last_24h),
        "by_sku": by_sku,
        "by_severity": by_severity,
        "complaint_spike": len(last_24h) > 3
    }
