import json
import sys
import os
from datetime import datetime
import json

# Clear data before each test run
for file in ["data/org_incidents.json", "data/org_stock.json"]:
    with open(file, "w") as f:
        json.dump([], f)

print("Data cleared. Starting fresh run...")

# Enforce import path to find main and utils
sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))

from fastapi.testclient import TestClient
from main import app

client = TestClient(app)

def run_suite():
    results = {}
    print("=== STARTING SECURE OPTIFLOW MULTI-ORG API TEST SUITE ===")
    
    # ── TEST 1: Create Organizations ──
    print("\n[TEST 1] Creating Organizations...")
    org1_res = client.post("/api/v1/orgs", json={"name": "Karachi Relief NGO", "org_type": "ngo"})
    org2_res = client.post("/api/v1/orgs", json={"name": "City Pharma Distributor", "org_type": "pharma"})
    
    org1_data = org1_res.json()
    org2_data = org2_res.json()
    
    print(f"NGO Org Response: {json.dumps(org1_data, indent=2)}")
    print(f"Pharma Org Response: {json.dumps(org2_data, indent=2)}")
    
    results["test_1_org_1"] = org1_data
    results["test_1_org_2"] = org2_data
    
    org_id = org1_data.get("org", {}).get("org_id", "org-b8f3e58c")

    # ── SECURE LOGIN: Acquire JWT Token ──
    print("\n[AUTH] Logging in as NGO Manager (ahmed@karachirelief.org)...")
    login_res = client.post("/api/v1/auth/login", json={
        "email": "ahmed@karachirelief.org",
        "password": "ngo123"
    })
    
    if login_res.status_code != 200:
        print(f"AUTH FAILED: {login_res.text}")
        sys.exit(1)
        
    login_data = login_res.json()
    token = login_data.get("access_token")
    headers = {"Authorization": f"Bearer {token}"}
    print("[AUTH SUCCESS] JWT token acquired.")

    # ── TEST 2: Ingest Stock ──
    print(f"\n[TEST 2] Ingesting Stock under secure context...")
    stock_res = client.post("/api/v1/ingest/stock", headers=headers, json={
        "depot_id": "depot-site-01",
        "depot_name": "SITE Industrial Hub",
        "zone": "SITE",
        "sku": "MED-001",
        "item_name": "Panadol Extra 500mg",
        "quantity": 150,
        "min_threshold": 500
    })
    stock_data = stock_res.json()
    print(f"Stock Ingest Response: {json.dumps(stock_data, indent=2)}")
    results["test_2_stock"] = stock_data

    # ── TEST 3: Ingest 3 Critical Incidents ──
    print("\n[TEST 3] Ingesting 3 Critical Incidents for Korangi...")
    incidents = [
        {"reporter_name": "Driver Tariq", "reporter_role": "driver", "location_zone": "Korangi", "sku": "MED-001", "message": "Zero stock at Korangi supply point, urgent shortage", "severity": "critical"},
        {"reporter_name": "Field Worker Asma", "reporter_role": "operator", "location_zone": "Korangi", "sku": "MED-001", "message": "Confirmed zero physical stock, patients waiting", "severity": "critical"},
        {"reporter_name": "Supervisor Bilal", "reporter_role": "operator", "location_zone": "Korangi", "sku": "MED-001", "message": "Third report - shelves empty despite system showing stock", "severity": "critical"}
    ]
    
    test_3_results = []
    for idx, inc in enumerate(incidents, 1):
        res = client.post("/api/v1/ingest/incident", headers=headers, json=inc)
        res_data = res.json()
        print(f"Incident {idx} Response: {json.dumps(res_data, indent=2)}")
        test_3_results.append(res_data)
    results["test_3_incidents"] = test_3_results

    # ── TEST 4: Check Zone Risk Map ──
    print("\n[TEST 4] Fetching Zone Risk Map...")
    risk_res = client.get("/api/v1/zone-risk-map", headers=headers)
    risk_data = risk_res.json()
    print(f"Zone Risk Map Response: {json.dumps(risk_data, indent=2)}")
    results["test_4_risk_map"] = risk_data

    # ── TEST 5: Check Full Dashboard ──
    print("\n[TEST 5] Fetching Main Command Dashboard Payload...")
    dash_res = client.get("/api/v1/dashboard", headers=headers)
    dash_data = dash_res.json()
    print(f"Dashboard Response: {json.dumps(dash_data, indent=2)}")
    results["test_5_dashboard"] = dash_data

    # ── TEST 6: Check Contradictions ──
    print("\n[TEST 6] Fetching Contradictions Anomaly Report...")
    contra_res = client.get("/api/v1/contradictions", headers=headers)
    contra_data = contra_res.json()
    print(f"Contradictions Response: {json.dumps(contra_data, indent=2)}")
    results["test_6_contradictions"] = contra_data

    # ── TEST 7: Movement Ingest ──
    print("\n[TEST 7] Ingesting Logistics Cargo Movement...")
    move_res = client.post("/api/v1/ingest/movement", headers=headers, json={
        "driver_name": "Ahmed Khan",
        "vehicle_id": "KHI-TRK-042",
        "origin_zone": "SITE",
        "destination_zone": "Korangi",
        "sku": "MED-001",
        "quantity": 200,
        "status": "in_transit"
    })
    move_data = move_res.json()
    print(f"Movement Ingest Response: {json.dumps(move_data, indent=2)}")
    results["test_7_movement"] = move_data

    # Save to file
    out_path = os.path.join(os.path.dirname(__file__), "data", "test_results.json")
    with open(out_path, "w") as f:
        json.dump(results, f, indent=2)
    print(f"\n[SUCCESS] All 7 secure tests executed and saved to {out_path}!")

if __name__ == "__main__":
    run_suite()
