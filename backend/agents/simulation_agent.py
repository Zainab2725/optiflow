import os
import json
import google.generativeai as genai

class SimulationAgent:
    """
    Action Simulation Agent
    Simulates the performance, routing, and inventory impact of executing a chosen logistics decision strategy.
    Operates strictly as a sandbox/simulation layer, displaying before vs. after operational states.
    """
    def __init__(self):
        self.api_key = os.getenv("GEMINI_API_KEY")
        if self.api_key:
            genai.configure(api_key=self.api_key)
        self.model_name = "gemini-2.5-flash"

    def simulate(self, decision_plan: dict) -> dict:
        """
        Simulates the decision plan's actions and returns before vs after states.
        """
        if not self.api_key:
            return self._fallback_simulate(decision_plan, error_msg="GEMINI_API_KEY not configured")

        plan_json = json.dumps(decision_plan, indent=2)

        prompt = f"""You are the Action Simulation Agent for OptiFlow logistics intelligence platform.
Your task is to take a proposed decision action and simulate its operational impact.

1. Construct a logical 'before_state' representing the current troubled logistics status (e.g. routes, transit status, stock levels, delays).
2. Construct a logical 'after_state' showing the resolved/optimized situation after applying the decision action parameters.
3. Calculate or estimate the logical 'impact_metrics' (e.g. delay_reduction as a percentage string, risk_reduction level, and other relevant metrics).

DECISION PLAN:
\"\"\"
{plan_json}
\"\"\"

You MUST respond with a single, strictly valid JSON object. No markdown block, no comments, no extra text.
JSON Schema:
{{
  "before_state": {{
    "route": "string showing routes (e.g., A → B → C)",
    "status": "string (e.g., delayed / stockout risk)",
    "stock_level": "string description (optional)"
  }},
  "after_state": {{
    "route": "string showing optimized routes (e.g., A → D → C)",
    "status": "string (e.g., optimized / dispatched)",
    "stock_level": "string description (optional)"
  }},
  "impact_metrics": {{
    "delay_reduction": "string percentage (e.g. 65%)",
    "risk_reduction": "LOW | MEDIUM | HIGH | CRITICAL",
    "additional_metric": "string (optional)"
  }}
}}
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
            if "before_state" not in parsed or "after_state" not in parsed or "impact_metrics" not in parsed:
                raise ValueError("Missing schema fields in simulation agent response")
                
            return parsed
        except Exception as e:
            print(f"SimulationAgent Gemini error: {e}. Falling back to rule-based simulator.")
            return self._fallback_simulate(decision_plan, error_msg=str(e))

    def _fallback_simulate(self, decision_plan: dict, error_msg: str = "") -> dict:
        """
        Robust fallback operational simulation model.
        """
        action = decision_plan.get("selected_action", {})
        action_type = action.get("type", "ROUTE_CHANGE")
        params = action.get("parameters", {})

        if action_type == "ROUTE_CHANGE":
            blocked = params.get("blocked_road", "M9 Motorway")
            alt = params.get("alternative_route", "Lyari Expressway bypass")
            sku = params.get("sku", "INS-001")
            
            return {
                "before_state": {
                    "route": f"Karachi Port → {blocked} → Depot Depot",
                    "status": "delayed (blocked by flood hazard)",
                    "stock_level": f"low ({sku} insulin critical warning)"
                },
                "after_state": {
                    "route": f"Karachi Port → {alt} → Depot Depot",
                    "status": "optimized (emergency dispatch active)",
                    "stock_level": "replenished (+500 units, normalized)"
                },
                "impact_metrics": {
                    "delay_reduction": "85%",
                    "risk_reduction": "CRITICAL",
                    "alternative_route_safety": "95%",
                    "eta_improvement": "4.5 hours earlier"
                },
                "_fallback_active": True,
                "_fallback_reason": error_msg
            }
            
        elif action_type == "RESTOCK":
            return {
                "before_state": {
                    "route": "Standard supplier dispatch",
                    "status": "stockout danger",
                    "stock_level": "depleted below threshold"
                },
                "after_state": {
                    "route": "Emergency express dispatch",
                    "status": "dispatched",
                    "stock_level": "restocked to safe threshold"
                },
                "impact_metrics": {
                    "delay_reduction": "50%",
                    "risk_reduction": "HIGH",
                    "stock_replenished_percentage": "100%"
                },
                "_fallback_active": True,
                "_fallback_reason": error_msg
            }
            
        else:
            return {
                "before_state": {
                    "route": "Standard route",
                    "status": "delayed"
                },
                "after_state": {
                    "route": "Standard route with delay notice",
                    "status": "notified"
                },
                "impact_metrics": {
                    "delay_reduction": "0%",
                    "risk_reduction": "MEDIUM"
                },
                "_fallback_active": True,
                "_fallback_reason": error_msg
            }
