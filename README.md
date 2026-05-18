# OptiFlow — Karachi Urban Crisis Intelligence System

## 1. What It Does
OptiFlow is an AI-powered logistics and supply chain intelligence platform tailored for the Karachi pharmaceutical sector. It ingests diverse unstructured data—from news and weather to warehouse stock and customer complaints—to proactively detect stockouts and route disruptions before they cause critical failures. 

## 2. Architecture Overview
- **Backend:** High-performance REST APIs built with Python and **FastAPI**.
- **Mobile App:** Cross-platform front-end built with **Flutter** and **Firebase** for real-time state and user management.
- **AI Engine:** Powered by Google's **Gemini AI** to parse complex, unstructured signals and deduce contradictions in supply chain logistics.

## 3. How Antigravity is Used
Antigravity was crucial in the rapid orchestration of this project, managing the agent workflow, and structuring the execution of complex tasks. It planned the backend integration, developed the Flutter frontend, and ensured seamless communication between the multi-step agentic engine and our APIs.

## 4. Eight Data Sources Ingested
OptiFlow's intelligence relies on the real-time aggregation of 8 diverse data sources:
1. Google Sheets Warehouse Stock Data (CSV)
2. OpenWeatherMap (Karachi Weather Data)
3. ExchangeRate-API (Currency Constraints & Pricing)
4. In-App User Complaints (Real-time feedback)
5. Pakistan Business RSS Feeds (Dawn, ProPakistani, Tribune)
6. NewsData.io (Pakistan Business & Health News)
7. Google Trends / Media Trend Scanner (Custom RSS analysis)
8. Simulated Supplier Delay Feeds

## 5. The 5-Step Agentic Action Chain
When a critical logistical contradiction is detected, the AI initiates a 5-step action chain:
1. **Validate Stock:** Cross-references alerts against warehouse records.
2. **Notify Procurement:** Drafts and prepares urgent escalation emails to procurement teams.
3. **Simulate Emergency Order:** Checks budget constraints and simulates a fast-tracked PO with an alternate supplier.
4. **Update Customer Notifications:** Drafts contextual, reassuring SMS messages for affected users on the ground.
5. **Schedule Monitoring:** Sets up high-frequency active monitoring parameters for the affected SKUs.

## 6. How To Run It
**Start the Backend:**
```bash
cd backend
# Activate your virtual environment first
uvicorn main:app --host 127.0.0.1 --port 8000 --reload
```

**Run the Flutter App:**
```bash
cd optiflow_app
flutter run -d windows
```

## 7. APIs Used
- Google Gemini AI
- OpenWeather API
- ExchangeRate API
- NewsData API
- Firebase (Auth, Analytics, Core)

## 8. Hackathon Requirements Mapping
1. **Mobile App (MUST)** — DONE
2. **Ingest unstructured input** — DONE
3. **Extract key insights** — DONE
4. **Analyze implications** — DONE
5. **Generate recommended actions** — DONE
6. **Simulate execution of at least one action** — DONE
7. **Show before vs after state** — DONE
8. **Agentic workflow with multiple steps** — DONE
9. **Agent trace / logs** — DONE
10. **Demo video** — DONE
11. **README** — DONE
