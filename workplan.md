# Workplan – Autonomous Content‑to‑Action Agent (Challenge 1)

## 🎯 Goal
Create an end‑to‑end system that ingests unstructured content, extracts insights, decides on actions, simulates execution, and presents the resulting state – all orchestrated by **Google Antigravity**.

## 📦 High‑Level Phases
| Phase | Description | Antigravity Role |
|------|-------------|-----------------|
| **1️⃣ Content Ingestion** | Accept text, PDF, URL, or uploaded file. Normalise to plain string. | Provides a **workplan** task to call the `FileReader` tool, split large payloads, and store raw input in `session.state.raw`. |
| **2️⃣ Insight Extraction** | Run the **Insight Agent** – a prompt chain that extracts signals, confidence scores and reasons. | Executes a **reasoning step** using Antigravity’s `run_command` to invoke the LLM, stores structured signals in `session.insights`. |
| **3️⃣ Impact Analysis** | Map each insight to business impact (revenue loss, cost increase, risk). | Generates a **decision‑orchestrator** step that scores impacts, adds a `riskLevel` field. |
| **4️⃣ Action Generation** | Produce concrete, domain‑specific recommendations. | Antigravity creates a **task** that calls the Action Generation prompt, output stored in `session.actions`. |
| **5️⃣ Simulation** | Execute a mock API (e.g., `/campaign/create`, `/pricing/update`). | Antigravity runs the **simulation engine** – a sandboxed HTTP call, captures `before/after` snapshots. |
| **6️⃣ Outcome Presentation** | Visualize before‑vs‑after, render logs, and update UI. | Antigravity writes an **Agent Trace Log** and populates `session.result` for the Flutter front‑end. |

## 🛠️ Antigravity‑Centric Workflow
1. **Workplan Generation** – Antigravity creates a JSON workplan outlining subtasks (ingest, insight, decision, simulate).
2. **Task Queue** – Each subtask becomes a **Task** artifact (`tasks.md`). Antigravity schedules them, monitors status, and retries on failure.
3. **Reasoning Steps** – For each task Antigravity logs a **reasoning block** (prompt, response, confidence).
4. **Decision Flow** – The **Decision Orchestrator** aggregates scores, selects the highest‑risk action, and stores a deterministic `actionId`.
5. **Action Execution** – Antigravity invokes a mock API via `run_command` or `http_request` tool, captures response.
6. **Trace Logging** – At the end of every run Antigravity writes a human‑readable block to `logs/agent_trace.log` following the specification already defined.

## 📁 Deliverables
- `README.md` – already prepared (high‑impact documentation).
- `logs/agent_trace.log` – structured log format.
- `logs/agent_runs.json` – JSON schema for aggregated runs.
- **Workplan** – this file.
- **Tasks Plan** – `tasks.md` (see next file).
- **Example Trace** – `example_trace.md` (shows a complete execution for a flood‑disruption scenario).
- Mobile app (`optiflow_app`) with Agent Console screen displaying live trace.

## ⏱️ Timeline (for judges)
| Week | Milestone |
|------|-----------|
| 1 | Set up Antigravity workplan, implement ingestion & insight prompts. |
| 2 | Build decision orchestrator, define risk‑scoring matrix. |
| 3 | Implement action generation & simulation sandbox. |
| 4 | Integrate Flutter UI, connect live trace view. |
| 5 | Polish UX, generate demo video, final testing. |

## ✅ Success Criteria
- ✅ End‑to‑end flow visible in the mobile app.
- ✅ Structured logs automatically emitted.
- ✅ At least one simulated action (e.g., create flood‑alert campaign) with before/after state.
- ✅ All orchestration logic resides inside Antigravity – no external workflow engine.

---
*Prepared for the Google Antigravity Hackathon – fully compliant with Challenge 1 requirements.*
