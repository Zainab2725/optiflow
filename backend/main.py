from fastapi import FastAPI, Depends, HTTPException, status, Request
from fastapi.staticfiles import StaticFiles
from fastapi.responses import FileResponse
from fastapi.middleware.cors import CORSMiddleware
from utils.data_sources import fetch_all_sources
from utils.complaint_store import save_complaint, get_complaints, get_complaint_summary
from agents.contradiction_engine import SupplyChainAgent
from agents.action_chain import run_action_chain
# WhatsApp alerts system removed
from utils.stock_predictor import run_stock_predictions
from utils.route_optimizer import optimize_route
import google.generativeai as genai
import os
from dotenv import load_dotenv
from pydantic import BaseModel
from typing import Optional, List
from google.cloud import pubsub_v1
import json
from datetime import datetime
import uuid



from utils.jwt_helper import encode_jwt, decode_jwt
from utils.org_store import (
    create_org, get_orgs, get_org,
    save_org_stock, get_org_stock, get_stock_summary,
    save_org_incident, get_org_incidents,
    get_zone_risk_map, detect_org_contradictions
)
from utils.pubsub_handler import publish_to_pubsub

load_dotenv(os.path.join(os.path.dirname(__file__), ".env"))
genai.configure(api_key=os.getenv("GEMINI_API_KEY"))

app = FastAPI(
    title="OptiFlow Secure API",
    description="Multi-tenant Supply Chain Intelligence Platform for Pakistan",
    version="2.0.0"
)
from fastapi.middleware.cors import CORSMiddleware

app.add_middleware(
    CORSMiddleware,
    allow_origins=["*"],
    allow_credentials=True,
    allow_methods=["*"],
    allow_headers=["*"],
)

# Add after app creation, before routes:
frontend_dir = os.path.join(os.path.dirname(__file__), "frontend")
if os.path.exists(frontend_dir):
    app.mount("/static", StaticFiles(directory=frontend_dir), 
              name="static")

# ════════════════════════════════════════
# SECURITY DEPENDENCIES & CONTEXT
# ════════════════════════════════════════

def get_current_user(request: Request) -> dict:
    auth_header = request.headers.get("Authorization")
    if not auth_header:
        raise HTTPException(
            status_code=status.HTTP_401_UNAUTHORIZED,
            detail="Missing Authorization Token"
        )
    if not auth_header.startswith("Bearer "):
        raise HTTPException(
            status_code=status.HTTP_401_UNAUTHORIZED,
            detail="Token type must be Bearer"
        )
    token = auth_header.split(" ")[1]
    try:
        payload = decode_jwt(token)
        return payload
    except ValueError as e:
        raise HTTPException(
            status_code=status.HTTP_401_UNAUTHORIZED,
            detail=str(e)
        )

def require_roles(allowed_roles: List[str]):
    def dependency(current_user: dict = Depends(get_current_user)):
        if current_user.get("role") not in allowed_roles:
            raise HTTPException(
                status_code=status.HTTP_403_FORBIDDEN,
                detail="Access Denied: Insufficient Role Permissions"
            )
        return current_user
    return dependency

# --- Models ---
class LoginInput(BaseModel):
    email: str
    password: str

class ComplaintInput(BaseModel):
    customer_name: str
    sku: str
    product_name: str
    message: str
    severity: str = "medium"
    location: Optional[str] = None

class InventoryItem(BaseModel):
    sku: str
    product_name: str
    quantity: int
    unit: str
    last_updated: str
    warehouse: str

class ComplaintItem(BaseModel):
    customer_name: str
    sku: str
    product_name: str
    message: str
    severity: str
    location: Optional[str] = None

class AnalyzeRequest(BaseModel):
    inventory: Optional[List[InventoryItem]] = None
    complaints: Optional[List[ComplaintItem]] = None

class CreateOrgInput(BaseModel):
    name: str
    org_type: str = "ngo"

class SignupOrgInput(BaseModel):
    organization_name: str
    organization_type: str = "NGO"
    custom_sheet_url: Optional[str] = None
    admin_name: str
    email: str
    password: str

class InviteUserInput(BaseModel):
    name: str
    email: str
    role: str = "driver"

class IngestStockInput(BaseModel):
    depot_id: str
    depot_name: str
    zone: str
    sku: str
    item_name: str
    quantity: int
    min_threshold: int = 500

class IngestIncidentInput(BaseModel):
    reporter_name: str
    reporter_role: str = "driver"
    location_zone: str
    sku: Optional[str] = None
    message: str
    severity: str = "high"

class IngestMovementInput(BaseModel):
    driver_name: str
    vehicle_id: str
    origin_zone: str
    destination_zone: str
    sku: str
    quantity: int
    status: str = "in_transit"

# --- Health ---
@app.get("/health")
async def health_check():
    return {"status": "healthy", "service": "optiflow-secure-backend"}

# --- Auth ---
@app.post("/api/v1/auth/login")
@app.post("/auth/login")
def login(payload: LoginInput):
    users_path = os.path.join(os.path.dirname(__file__), "data", "users.json")
    if not os.path.exists(users_path):
        raise HTTPException(status_code=500, detail="Users credential store not configured")
    with open(users_path, "r") as f:
        users = json.load(f)
    
    user = next((u for u in users if u["email"].lower() == payload.email.lower() and u["password"] == payload.password), None)
    if not user:
        raise HTTPException(status_code=401, detail="Invalid email or password")
    
    token = encode_jwt({
        "user_id": user["user_id"],
        "org_id": user["org_id"],
        "role": user["role"]
    })
    
    return {
        "access_token": token,
        "token_type": "bearer",
        "user": {
            "user_id": user["user_id"],
            "name": user["name"],
            "role": user["role"],
            "org_id": user["org_id"],
            "org_name": user.get("org_name", "Unknown Org")
        }
    }

@app.post("/api/v1/auth/signup-org", status_code=201)
def signup_org(payload: SignupOrgInput):
    users_path = os.path.join(
        os.path.dirname(__file__), "data", "users.json"
    )
    orgs_path = os.path.join(
        os.path.dirname(__file__), "data", "organizations.json"
    )
    
    try:
        with open(users_path, "r") as f:
            users = json.load(f)
    except:
        users = []
    
    if any(u["email"].lower() == payload.email.lower() for u in users):
        raise HTTPException(
            status_code=400,
            detail="Email already registered"
        )
    
    org_id = f"org-{str(uuid.uuid4())[:8]}"
    org = {
        "org_id": org_id,
        "name": payload.organization_name,
        "type": payload.organization_type,
        "custom_sheet_url": payload.custom_sheet_url,
        "created_at": datetime.utcnow().isoformat()
    }
    
    try:
        with open(orgs_path, "r") as f:
            orgs = json.load(f)
    except:
        orgs = []
    orgs.append(org)
    with open(orgs_path, "w") as f:
        json.dump(orgs, f, indent=2)
    
    user_id = f"usr-{str(uuid.uuid4())[:8]}"
    new_user = {
        "user_id": user_id,
        "name": payload.admin_name,
        "email": payload.email,
        "password": payload.password,
        "org_id": org_id,
        "org_name": payload.organization_name,
        "role": "admin"
    }
    users.append(new_user)
    with open(users_path, "w") as f:
        json.dump(users, f, indent=2)
    
    token = encode_jwt({
        "user_id": user_id,
        "org_id": org_id,
        "role": "admin"
    })
    
    return {
        "token": token,
        "user": {
            "user_id": user_id,
            "name": payload.admin_name,
            "email": payload.email,
            "role": "admin",
            "org_id": org_id,
            "org_name": payload.organization_name
        },
        "organization": org
    }

@app.post("/api/v1/users/invite", status_code=201)
def invite_user(
    payload: InviteUserInput,
    current_user: dict = Depends(require_roles(["admin", "manager"]))
):
    users_path = os.path.join(
        os.path.dirname(__file__), "data", "users.json"
    )
    
    try:
        with open(users_path, "r") as f:
            users = json.load(f)
    except:
        users = []
    
    if any(u["email"].lower() == payload.email.lower() for u in users):
        raise HTTPException(
            status_code=400,
            detail="Email already exists"
        )
    
    user_id = f"usr-{str(uuid.uuid4())[:8]}"
    new_user = {
        "user_id": user_id,
        "name": payload.name,
        "email": payload.email,
        "password": "welcome123",
        "org_id": current_user["org_id"],
        "org_name": current_user.get("org_name", ""),
        "role": payload.role
    }
    users.append(new_user)
    with open(users_path, "w") as f:
        json.dump(users, f, indent=2)
    
    return {
        "status": "invited",
        "user": new_user,
        "default_password": "welcome123",
        "message": f"{payload.name} added to your organization"
    }

# ════════════════════════════════════════
# MULTI-TENANT LOGISTICS & STOCK
# ════════════════════════════════════════

@app.post("/api/v1/ingest/stock", status_code=201)
@app.post("/ingest/stock", status_code=201)
async def api_ingest_stock(payload: IngestStockInput, current_user: dict = Depends(require_roles(["admin", "manager", "pharma_admin"]))):
    org_id = current_user["org_id"]
    event_data = {
        "event_type": "stock_update",
        "org_id": org_id,
        "depot_id": payload.depot_id,
        "zone": payload.zone,
        "sku": payload.sku,
        "item_name": payload.item_name,
        "quantity": payload.quantity,
        "timestamp": datetime.utcnow().isoformat()
    }

    published, message_id = publish_to_pubsub(event_data)

    record = payload.dict()
    record["org_id"] = org_id # Overwrite to prevent spoofing
    saved = save_org_stock(record)

    threshold_breached = payload.quantity < payload.min_threshold

    return {
        "status": "ingested",
        "record_id": saved.get("id"),
        "event_published": published,
        "message_id": message_id,
        "rules_evaluated": {
            "stock_threshold_breached": threshold_breached,
            "current_level": payload.quantity,
            "min_limit": payload.min_threshold,
            "status": "CRITICAL" if threshold_breached else "NORMAL"
        }
    }

async def get_merged_stock_ledger(org_id: str) -> dict:
    # 1. Fetch backend sheet data
    from utils.data_sources import fetch_warehouse_csv
    from utils.org_store import get_org
    
    org = get_org(org_id)
    sheet_url = org.get("custom_sheet_url") if org else None
    
    sheet_records = []
    try:
        sheet_res = await fetch_warehouse_csv(sheet_url)
        if "data" in sheet_res and "records" in sheet_res["data"]:
            sheet_records = sheet_res["data"]["records"]
    except Exception as e:
        print(f"Error fetching warehouse sheet: {e}")
        
    # 2. Get local overrides from org_stock.json
    local_records = get_org_stock(org_id)
    
    # Helper to map warehouse name to zone
    def get_zone_for_warehouse(wh: str) -> str:
        w = str(wh).lower()
        if "clifton" in w: return "Clifton"
        if "saddar" in w: return "Saddar"
        if "malir" in w: return "Malir"
        if "site" in w: return "SITE"
        if "korangi" in w: return "Korangi"
        if "lyari" in w or "keamari" in w: return "Lyari"
        if "orangi" in w: return "Orangi"
        if "defence" in w: return "Defence"
        if "gulshan" in w: return "Gulshan"
        return "Saddar"
        
    # 3. Merge sheet data with local overrides
    merged_records = []
    local_map = {(r.get("sku"), r.get("zone")): r for r in local_records if r.get("sku") and r.get("zone")}
    
    # If we have sheet data, use it as the base
    if sheet_records:
        for row in sheet_records:
            sku = row.get("sku")
            if not sku:
                continue
            zone = get_zone_for_warehouse(row.get("warehouse", "Saddar Depot"))
            key = (sku, zone)
            if key in local_map:
                # Use local override (which has updated quantity from ingest/dispatch)
                merged_records.append(local_map[key])
            else:
                # Construct stock item from Google Sheet
                qty = int(row.get("quantity", 0))
                # Set default min_threshold to 200 or 1000 depending on qty/sku
                min_threshold = 1000 if sku.startswith("FUEL") or qty > 500 else 200
                
                merged_records.append({
                    "id": f"sheet-{sku.lower()}-{zone.lower().replace(' ', '-')}",
                    "org_id": org_id,
                    "depot_id": f"depot-{zone.lower()}",
                    "depot_name": row.get("warehouse", f"{zone} Depot"),
                    "zone": zone,
                    "sku": sku,
                    "item_name": row.get("product_name", sku),
                    "quantity": qty,
                    "min_threshold": min_threshold,
                    "unit": row.get("unit", "units"),
                    "threshold_breached": qty < min_threshold,
                    "status": "CRITICAL" if qty < min_threshold else "NORMAL"
                })
    else:
        # Fallback to local_records if sheet fetch failed
        merged_records = local_records

    # Re-compute summary based on merged records
    critical = [s for s in merged_records if s.get("status") == "CRITICAL"]
    by_zone = {}
    for s in merged_records:
        zone = s.get("zone", "unknown")
        by_zone[zone] = by_zone.get(zone, 0) + 1
        
    summary = {
        "total_records": len(merged_records),
        "critical_count": len(critical),
        "normal_count": len(merged_records) - len(critical),
        "by_zone": by_zone,
        "critical_skus": [s.get("sku") for s in critical]
    }
    
    return {
        "records": merged_records,
        "summary": summary
    }

@app.get("/api/v1/stock")
@app.get("/stock")
async def api_get_stock(current_user: dict = Depends(require_roles(["admin", "manager", "pharma_admin"]))):
    org_id = current_user["org_id"]
    return await get_merged_stock_ledger(org_id)

# ════════════════════════════════════════
# MULTI-TENANT INCIDENTS
# ════════════════════════════════════════

@app.post("/api/v1/ingest/incident", status_code=201)
@app.post("/ingest/incident", status_code=201)
async def api_ingest_incident(payload: IngestIncidentInput, current_user: dict = Depends(require_roles(["admin", "manager", "pharma_admin", "field_operator", "driver"]))):
    org_id = current_user["org_id"]
    event_data = {
        "event_type": "incident_report",
        "org_id": org_id,
        "reporter_name": payload.reporter_name,
        "reporter_role": payload.reporter_role,
        "zone": payload.location_zone,
        "sku": payload.sku,
        "message": payload.message,
        "severity": payload.severity,
        "timestamp": datetime.utcnow().isoformat()
    }

    published, message_id = publish_to_pubsub(event_data)

    record = payload.dict()
    record["org_id"] = org_id # Overwrite to prevent spoofing
    saved = save_org_incident(record)

    # Save to global complaint store
    save_complaint({
        "customer_name": f"[{org_id.upper()}] {payload.reporter_name} ({payload.reporter_role})",
        "sku": payload.sku or "GENERAL",
        "product_name": payload.message[:40] + "...",
        "message": payload.message,
        "severity": payload.severity,
        "location": payload.location_zone
    })

    risk_level = "GREEN"
    if payload.severity == "critical":
        risk_level = "RED"
    elif payload.severity == "high":
        risk_level = "YELLOW"

    return {
        "status": "ingested",
        "incident_id": saved.get("id"),
        "event_published": published,
        "message_id": message_id,
        "rules_evaluated": {
            "location_risk_tagged": risk_level,
            "zone": payload.location_zone,
            "severity": payload.severity
        }
    }

@app.get("/api/v1/incidents")
@app.get("/incidents")
async def api_get_incidents(zone: str = None, current_user: dict = Depends(require_roles(["admin", "manager", "pharma_admin", "field_operator"]))):
    org_id = current_user["org_id"]
    org_incidents = get_org_incidents(org_id, zone)
    all_incidents = get_org_incidents(None, zone)
    
    # Dynamically inject events from all 8 live sources as simulated public incidents!
    try:
        from utils.data_sources import fetch_all_sources
        sources = await fetch_all_sources()
        
        # 1. Weather Event (Only if logistics risk is HIGH)
        w = sources.get("weather", {}).get("data", {})
        if w and w.get("logistics_risk") == "HIGH":
            all_incidents.append({
                "id": "ai-weather-alert",
                "reporter_name": "AI Weather Monitor",
                "reporter_role": "AI agent",
                "location_zone": "Clifton",
                "sku": "GENERAL",
                "message": f"WEATHER HAZARD: Extreme logistics safety risk due to weather condition: {w.get('description', 'Heavy Rain')}. Possible flooded roads.",
                "severity": "CRITICAL",
                "org_id": "public",
                "timestamp": datetime.utcnow().isoformat(),
                "resolved": False,
                "risk_tag": "RED"
            })
            
        # 2. Supplier Delay Events (Only major supplier logistics disruptions)
        delays = sources.get("supplier_feed", {}).get("data", {}).get("active_delays", [])
        for idx, d in enumerate(delays):
            if d.get("severity") in ["HIGH", "CRITICAL"]:
                all_incidents.append({
                    "id": f"ai-supplier-delay-{idx}",
                    "reporter_name": "AI Supplier Channel",
                    "reporter_role": "AI agent",
                    "location_zone": "SITE",
                    "sku": d.get("sku", "GENERAL"),
                    "message": f"SUPPLIER DELAY: Shipment from {d.get('supplier', 'Supplier')} delayed by {d.get('delay_days', 3)} days. Reason: {d.get('reason', 'M9 motorway partial closure')}.",
                    "severity": "HIGH",
                    "org_id": "public",
                    "timestamp": datetime.utcnow().isoformat(),
                    "resolved": False,
                    "risk_tag": "YELLOW"
                })
            
        # 3. Google Trends / Media Trend Event (Only if actual critical panic spikes are detected)
        trends = sources.get("google_trends", {}).get("data", {})
        if trends and trends.get("public_panic_signal"):
            all_incidents.append({
                "id": "ai-trend-panic",
                "reporter_name": "AI Media Monitor",
                "reporter_role": "AI agent",
                "location_zone": "Saddar",
                "sku": "GENERAL",
                "message": f"SHORTAGE ALERT: Elevated media panic signal scanned. Topic: {trends.get('trend_alert', 'Medicine scarcity')}.",
                "severity": "CRITICAL",
                "org_id": "public",
                "timestamp": datetime.utcnow().isoformat(),
                "resolved": False,
                "risk_tag": "RED"
            })
            
        # 4. RSS News matched feed (Only if logistics blockade/strike relevant)
        articles = sources.get("rss_news", {}).get("data", {}).get("articles", [])
        for idx, art in enumerate(articles[:4]):
            title_lower = art.get('title', '').lower()
            summary_lower = art.get('summary', '').lower()
            combined = title_lower + " " + summary_lower
            if any(k in combined for k in ["strike", "block", "close", "flood", "protest", "delay", "highway", "motorway", "shutdown"]):
                all_incidents.append({
                    "id": f"ai-news-{idx}",
                    "reporter_name": "AI RSS News Channel",
                    "reporter_role": "AI agent",
                    "location_zone": "Korangi",
                    "sku": "GENERAL",
                    "message": f"NEWS SCAN: {art.get('title', 'Supply Chain News')}.",
                    "severity": "MINOR",
                    "org_id": "public",
                    "timestamp": datetime.utcnow().isoformat(),
                    "resolved": False,
                    "risk_tag": "GREEN"
                })
    except Exception as e:
        print(f"Failed to inject dynamic AI incidents: {e}")

    # Re-filter by zone if zone filter was requested
    if zone:
        all_incidents = [i for i in all_incidents if i.get("location_zone", "").lower() == zone.lower()]

    return {
        "incidents": org_incidents,
        "karachi_incidents": all_incidents,
        "total": len(org_incidents),
        "total_karachi": len(all_incidents)
    }

# In-memory registry for vehicle movements to expose to the operational UI
_movements_db = []

@app.post("/api/v1/ingest/movement", status_code=201)
@app.post("/ingest/movement", status_code=201)
async def api_ingest_movement(payload: IngestMovementInput, current_user: dict = Depends(require_roles(["admin", "manager", "pharma_admin", "driver"]))):
    global _movements_db
    org_id = current_user["org_id"]
    event_data = {
        "event_type": "logistics_movement",
        "org_id": org_id,
        "driver": payload.driver_name,
        "vehicle": payload.vehicle_id,
        "from": payload.origin_zone,
        "to": payload.destination_zone,
        "sku": payload.sku,
        "quantity": payload.quantity,
        "status": payload.status,
        "timestamp": datetime.utcnow().isoformat()
    }

    published, message_id = publish_to_pubsub(event_data)
    _movements_db.insert(0, event_data)

    return {
        "status": "ingested",
        "event_published": published,
        "message_id": message_id,
        "movement": event_data
    }

@app.get("/api/v1/movements")
@app.get("/movements")
async def api_get_movements(current_user: dict = Depends(require_roles(["admin", "manager", "pharma_admin", "driver", "user"]))):
    global _movements_db
    org_id = current_user["org_id"]
    org_movements = [m for m in _movements_db if m.get("org_id") == org_id]
    return org_movements

# ════════════════════════════════════════
# INTELLIGENCE MAPS & CONTRADICTIONS
# ════════════════════════════════════════

@app.get("/api/v1/zone-risk-map")
@app.get("/zone-risk-map")
def api_zone_risk_map(current_user: dict = Depends(get_current_user)):
    risk_map = get_zone_risk_map()
    red_zones = [z for z, d in risk_map.items() if d["risk"] == "RED"]
    yellow_zones = [z for z, d in risk_map.items() if d["risk"] == "YELLOW"]
    return {
        "zone_risk_map": risk_map,
        "summary": {
            "red_zones": red_zones,
            "yellow_zones": yellow_zones,
            "total_zones": len(risk_map),
            "alert_zones": len(red_zones) + len(yellow_zones)
        },
        "generated_at": datetime.utcnow().isoformat()
    }

@app.get("/api/v1/contradictions")
@app.get("/contradictions")
async def api_contradictions(current_user: dict = Depends(require_roles(["admin", "manager", "pharma_admin"]))):
    org_id = current_user["org_id"]
    contradictions = detect_org_contradictions()
    
    # Isolate contradictions to ONLY those SKUs that belong to this organization's active stock ledger
    merged_stock = await get_merged_stock_ledger(org_id)
    org_skus = [s.get("sku") for s in merged_stock["records"]]
    org_contradictions = [c for c in contradictions if c.get("sku") in org_skus]
    
    return {
        "contradictions": org_contradictions,
        "total_found": len(org_contradictions),
        "generated_at": datetime.utcnow().isoformat()
    }

# ════════════════════════════════════════
# SECURE CENTRAL COMMAND DASHBOARD
# ════════════════════════════════════════

@app.get("/api/v1/dashboard")
async def api_dashboard_json(request: Request, current_user: dict = Depends(get_current_user)):
    from utils.complaint_store import get_complaint_summary
    
    org_id = current_user["org_id"]
    merged_stock = await get_merged_stock_ledger(org_id)
    stock_summary = merged_stock["summary"]
    incidents = get_org_incidents(org_id)
    zone_risk = get_zone_risk_map()
    contradictions = detect_org_contradictions()
    complaint_summary = get_complaint_summary()
    
    # Isolate anomalies to own org scope
    org_skus = [s.get("sku") for s in merged_stock["records"]]
    org_contradictions = [c for c in contradictions if c.get("sku") in org_skus]
    
    red_zones = [z for z, d in zone_risk.items() if d["risk"] == "RED"]

    return {
        "org_id": org_id,
        "role": current_user["role"],
        "user_id": current_user["user_id"],
        "overview": {
            "total_stock_records": stock_summary["total_records"],
            "critical_stock_count": stock_summary["critical_count"],
            "active_incidents": len(incidents),
            "red_zones": red_zones,
            "contradictions_found": len(org_contradictions),
            "complaint_spike": complaint_summary.get("complaint_spike", False)
        },
        "stock_summary": stock_summary,
        "zone_risk_map": zone_risk,
        "recent_incidents": incidents[:5],
        "contradictions": org_contradictions,
        "generated_at": datetime.utcnow().isoformat()
    }

@app.get("/dashboard")
async def get_dashboard(request: Request):
    auth_header = request.headers.get("Authorization")
    if auth_header:
        try:
            # If Bearer token is provided in GET request, return secure JSON response
            current_user = get_current_user(request)
            return await api_dashboard_json(request=request, current_user=current_user)
        except Exception:
            pass
            
    # Serve index.html static view for browser/frontend requests
    from fastapi.responses import HTMLResponse
    index_path = os.path.join(os.path.dirname(__file__), "frontend", "index.html")
    if not os.path.exists(index_path):
        return HTMLResponse(content="<h1>OptiFlow Command Center File Not Found</h1>", status_code=404)
    with open(index_path, "r", encoding="utf-8") as f:
        html_content = f.read()
    return HTMLResponse(content=html_content)

# ════════════════════════════════════════
# UNSECURED GENERAL TELEMETRY
# ════════════════════════════════════════

@app.get("/")
async def root():
    return {
        "message": "OptiFlow Enterprise Secure Backend is LIVE!",
        "version": "2.0.0",
        "status": "secure"
    }

@app.get("/demo")
async def serve_dashboard():
    index_path = os.path.join(
        os.path.dirname(__file__), "frontend", "index.html"
    )
    return FileResponse(index_path)

@app.get("/ingest")
async def ingest(keywords: str = None):
    kw_list = keywords.split(",") if keywords else None
    data = await fetch_all_sources(kw_list)
    return data

@app.get("/test-ai")
async def test_ai():
    model = genai.GenerativeModel("gemini-1.5-flash")
    response = model.generate_content(
        "You are a supply chain analyst. In one sentence, "
        "what is the biggest risk in Pakistan pharmaceutical supply chain right now?"
    )
    return {"response": response.text}

@app.post("/analyze")
async def analyze(request: AnalyzeRequest = None):
    ingest_data = await fetch_all_sources()
    complaint_summary = get_complaint_summary()

    if request and request.inventory:
        inventory = [item.dict() for item in request.inventory]
    else:
        warehouse_data = ingest_data.get("warehouse", {})
        inventory = warehouse_data.get("data", {}).get("records", [])

    if request and request.complaints:
        complaints = [c.dict() for c in request.complaints]
    else:
        complaints = get_complaints(limit=20)

    pkr_rate = ingest_data.get("currency", {}).get("data", {}).get("usd_to_pkr", 279.0)

    agent = SupplyChainAgent()
    analysis = agent.analyze_disparities(inventory, complaints)
    action_result = run_action_chain(analysis, inventory, complaints, pkr_rate)

    critical_alerts = [
        a for a in analysis.get("alerts", [])
        if a.get("risk_level") == "CRITICAL"
    ]

    GCP_PROJECT_ID = os.getenv("GCP_PROJECT_ID", "ai-seekho-hackathon-496416")
    PUBSUB_TOPIC = f"projects/{GCP_PROJECT_ID}/topics/supply-chain-alerts"

    pubsub_results = []
    from utils.pubsub_handler import is_gcp_configured
    if critical_alerts and is_gcp_configured():
        try:
            publisher = pubsub_v1.PublisherClient()
            for alert in critical_alerts:
                message_bytes = json.dumps(alert).encode("utf-8")
                future = publisher.publish(PUBSUB_TOPIC, message_bytes)
                pubsub_results.append({
                    "sku": alert.get("sku"),
                    "published": True,
                    "message_id": future.result(timeout=5)
                })
        except Exception as e:
            pubsub_results.append({
                "error": str(e),
                "note": "Pub/Sub alert processed locally"
            })
    elif critical_alerts:
        pubsub_results.append({
            "note": "Pub/Sub bypassed - credentials not configured. Alert processed locally."
        })

    return {
        "analysis_id": action_result.get("action_chain_id"),
        "timestamp": action_result.get("chain_timestamp"),
        "ai_analysis": analysis,
        "action_chain": action_result,
        "pubsub_alerts_sent": len(pubsub_results),
        "pubsub_results": pubsub_results,
        "sources_used": list(ingest_data.keys()),
        "ingest_summary": {
            "sources_healthy": ingest_data.get("meta", {}).get("sources_healthy", 0),
            "complaint_spike": complaint_summary.get("complaint_spike", False),
            "total_complaints": complaint_summary.get("total", 0),
            "pkr_rate": pkr_rate
        }
    }

@app.get("/predict/stock")
async def predict_stock():
    ingest_data = await fetch_all_sources()
    complaint_summary = get_complaint_summary()
    warehouse_data = ingest_data.get("warehouse", {})
    records = warehouse_data.get("data", {}).get("records", [])
    
    if not records:
        return {"error": "No warehouse records found to run predictions"}
        
    predictions = run_stock_predictions(records, complaint_summary)
    return predictions

@app.get("/analyze/status")
async def analyze_status():
    summary = get_complaint_summary()
    return {
        "agent_initialized": True,
        "complaint_spike": summary.get("complaint_spike", False),
        "total_complaints": summary.get("total", 0),
        "ready": True
    }

@app.get("/route")
async def route_optimization(
    request: Request,
    origin: str = "Hyderabad, Pakistan",
    destination: str = "Karachi, Pakistan"
):
    org_id = "org-demo"
    try:
        current_user = get_current_user(request)
        if current_user:
            org_id = current_user.get("org_id", "org-demo")
    except Exception:
        pass

    ingest_data = await fetch_all_sources()
    weather = ingest_data.get("weather", {}).get("data", {})
    dawn_articles = (
        ingest_data.get("dawn_rss", {}).get("data", {}).get("articles", [])
    )
    news_articles = (
        ingest_data.get("news", {}).get("data", {}).get("articles", [])
    )
    all_headlines = (
        [a.get("title", "") for a in dawn_articles] +
        [a.get("title", "") for a in news_articles]
    )
    result = await optimize_route(weather, all_headlines, origin, destination, org_id)
    return result

@app.post("/api/v1/orgs", status_code=201)
def api_create_org(payload: CreateOrgInput):
    org = create_org(payload.name, payload.org_type)
    return {"status": "created", "org": org}

@app.get("/api/v1/orgs")
def api_get_orgs():
    return {"organizations": get_orgs()}