import os
import json
from datetime import datetime
import google.generativeai as genai

class InsightAgent:
    """
    Insight Aggregation Agent
    Ingests raw unstructured text (news, weather, stock sheets, API signals)
    and extracts structured supply chain/logistics risk signals and confidence scores using Gemini.
    """
    def __init__(self):
        self.api_key = os.getenv("GEMINI_API_KEY")
        if self.api_key:
            genai.configure(api_key=self.api_key)
        self.model_name = "gemini-2.5-flash"

    def analyze(self, raw_input: str) -> dict:
        """
        Analyzes the unstructured input and extracts structured risk signals.
        """
        if not self.api_key:
            return self._fallback_analyze(raw_input, error_msg="GEMINI_API_KEY not configured")

        prompt = f"""You are the Insight Aggregation Agent for OptiFlow logistics intelligence platform.
Your task is to ingest unstructured reports, news articles, weather warnings, or inventory sheets, and extract structured risk signals.

Each signal must be:
- snake_case (e.g., "flood_risk_high", "road_block_detected", "stock_insulin_low", "delivery_scheduled")
- accompanied by a confidence score between 0.0 and 1.0 based on clarity and severity.

INPUT TEXT:
\"\"\"
{raw_input}
\"\"\"

You MUST respond with a single, strictly valid JSON object. No markdown block (do NOT wrap in ```json), no comments, no extra text.
JSON Schema:
{{
  "signals": [
    "signal_name_1",
    "signal_name_2"
  ],
  "confidence_scores": {{
    "signal_name_1": 0.95,
    "signal_name_2": 0.88
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
            # Validate structure
            if "signals" not in parsed or "confidence_scores" not in parsed:
                raise ValueError("Missing keys in Gemini response")
            return parsed
        except Exception as e:
            print(f"InsightAgent Gemini error: {e}. Falling back to rules-based extraction.")
            return self._fallback_analyze(raw_input, error_msg=str(e))

    def _fallback_analyze(self, raw_input: str, error_msg: str = "") -> dict:
        """
        Robust fallback parser if the Gemini API call fails.
        Guarantees correct structured formats for the hackathon demo scenarios.
        """
        input_lower = raw_input.lower()
        signals = []
        confidence_scores = {}

        # Scan for common patterns
        if "flood" in input_lower or "rain" in input_lower:
            signals.append("flood_risk_high")
            confidence_scores["flood_risk_high"] = 0.95
        if "block" in input_lower or "closed" in input_lower or "highway" in input_lower or "motorway" in input_lower:
            signals.append("road_block_detected")
            confidence_scores["road_block_detected"] = 0.90
        if "insulin" in input_lower or "stock low" in input_lower or "shortage" in input_lower:
            signals.append("stock_insulin_low")
            confidence_scores["stock_insulin_low"] = 0.98
        if "delivery" in input_lower or "scheduled" in input_lower or "route" in input_lower:
            signals.append("delivery_scheduled")
            confidence_scores["delivery_scheduled"] = 0.85

        # Fallback default if nothing is found
        if not signals:
            signals.append("general_monitoring")
            confidence_scores["general_monitoring"] = 0.50

        return {
            "signals": signals,
            "confidence_scores": confidence_scores,
            "_fallback_active": True,
            "_fallback_reason": error_msg
        }
