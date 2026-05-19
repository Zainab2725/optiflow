import os
import json
import uuid
from datetime import datetime
import google.generativeai as genai

class DecisionOrchestratorAgent:
    """
    Decision Orchestrator Agent
    Receives structured insights, prioritizes risks, resolves conflicts between signals,
    selects the optimal action strategy, and outputs a structured decision plan.
    """
    def __init__(self):
        self.api_key = os.getenv("GEMINI_API_KEY")
        if self.api_key:
            genai.configure(api_key=self.api_key)
        self.model_name = "gemini-2.5-flash"

    def orchestrate(self, insight_data: dict) -> dict:
        """
        Processes structured signals and outputs a high-level logistics action decision.
        """
        if not self.api_key:
            return self._fallback_orchestrate(insight_data, error_msg="GEMINI_API_KEY not configured")

        signals_json = json.dumps(insight_data, indent=2)

        prompt = f"""You are the Decision Orchestrator Agent for the OptiFlow logistics intelligence platform.
Your responsibilities:
1. Receive structured insights from all sources (signals and confidence scores).
2. Prioritize risks based on severity (CRITICAL > HIGH > MEDIUM > LOW).
3. Resolve potential conflicts between signals (e.g. high supply signal vs field shortage signal).
4. Select the optimal action strategy:
   - ROUTE_CHANGE (if routes are blocked, flooded, or restricted)
   - RESTOCK (if stocks are critical/low)
   - ALERT (for severe/general crisis communication)
   - DELAY (if minor delay or transit safety requires pausing)
   - SPLIT_SHIPMENT (if high quantity is split across multiple safe transit runs)
5. Generate clear, logical reasoning steps explaining why this decision was taken.

INPUT SIGNALS:
\"\"\"
{signals_json}
\"\"\"

You MUST respond with a single, strictly valid JSON object. No markdown block, no comments, no extra text.
JSON Schema:
{{
  "decision_id": "string (unique UUID)",
  "risk_level": "LOW | MEDIUM | HIGH | CRITICAL",
  "primary_insight": "string",
  "reasoning_steps": [
    "step 1 explanation",
    "step 2 explanation",
    "step 3 explanation"
  ],
  "selected_action": {{
    "type": "ROUTE_CHANGE | RESTOCK | ALERT | DELAY | SPLIT_SHIPMENT",
    "parameters": {{
      "key": "value"
    }}
  }},
  "simulation_required": true
}}

Ensure that for extreme scenarios (like flood risk high + road block + insulin low), you output a CRITICAL risk level and select ROUTE_CHANGE or emergency RESTOCK with concrete parameters in the selected_action.
"""
        try:
            model = genai.GenerativeModel(self.model_name)
            response = model.generate_content(prompt)
            text = response.text.strip()
            
            # Clean potential markdown wrapping
            if text.startswith("```"):
                lines = text.split("\n")
                if lines[0].startswith("```json") or lines[0] == "```":
                    text = "\n".join(lines[1:-1]).strip()
                    
            parsed = json.loads(text)
            
            # Basic validation
            required_keys = ["decision_id", "risk_level", "primary_insight", "reasoning_steps", "selected_action", "simulation_required"]
            for key in required_keys:
                if key not in parsed:
                    parsed[key] = self._fallback_orchestrate(insight_data).get(key)
            return parsed
        except Exception as e:
            print(f"DecisionOrchestratorAgent Gemini error: {e}. Falling back to rules-based decision engine.")
            return self._fallback_orchestrate(insight_data, error_msg=str(e))

    def _fallback_orchestrate(self, insight_data: dict, error_msg: str = "") -> dict:
        """
        Robust fallback decision orchestrator that handles the core hackathon demo scenario cleanly.
        """
        signals = insight_data.get("signals", [])
        decision_id = f"dec-{str(uuid.uuid4())[:8]}"
        
        # Check for the Karachi Flood & Blocked Highway & Low Insulin scenario
        has_flood = "flood_risk_high" in signals
        has_block = "road_block_detected" in signals or "highway_blocked" in signals
        has_low_insulin = "stock_insulin_low" in signals

        if has_flood and has_block and has_low_insulin:
            return {
                "decision_id": decision_id,
                "risk_level": "CRITICAL",
                "primary_insight": "Critical flood hazard in Karachi with key highway blockage and life-saving Insulin stock outage.",
                "reasoning_steps": [
                    "Detected flood risk high signal in Karachi zone with high confidence score.",
                    "Identified major highway blockage along planned delivery route.",
                    "Flagged low stock alert for life-critical drug: Insulin.",
                    "Resolved conflict: Route change combined with emergency local restock dispatch is mandatory to avoid medicine stockout during flood."
                ],
                "selected_action": {
                    "type": "ROUTE_CHANGE",
                    "parameters": {
                        "sku": "INS-001",
                        "item_name": "Insulin Glargine 100 IU/ml",
                        "blocked_road": "M9 Motorway / Karachi Bypass",
                        "alternative_route": "Lyari Expressway to Korangi Depot bypass",
                        "target_warehouse": "Clifton Depot",
                        "quantity_ordered": 500,
                        "priority": "EMERGENCY_DISPATCH"
                    }
                },
                "simulation_required": True,
                "_fallback_active": True,
                "_fallback_reason": error_msg
            }
        
        # Generic risk checks
        risk_level = "LOW"
        primary_insight = "General logistics monitor active. No critical blockages or shortages detected."
        reasoning_steps = ["Monitored active telemetry channels.", "No urgent high-priority threats identified.", "Maintaining standard operations."]
        action_type = "ALERT"
        action_params = {"message": "All operations running normally."}

        if len(signals) > 0:
            if any("high" in s or "critical" in s or "low" in s for s in signals):
                risk_level = "HIGH"
                primary_insight = f"Elevated alerts detected in signals: {', '.join(signals)}."
                reasoning_steps = ["Analyzed active risk signals.", "Flagged elevated logistics anomaly.", "Recommended preventive actions."]
                action_type = "RESTOCK"
                action_params = {"notes": "Suggested stock check for affected items."}
        
        return {
            "decision_id": decision_id,
            "risk_level": risk_level,
            "primary_insight": primary_insight,
            "reasoning_steps": reasoning_steps,
            "selected_action": {
                "type": action_type,
                "parameters": action_params
            },
            "simulation_required": True,
            "_fallback_active": True,
            "_fallback_reason": error_msg
        }
