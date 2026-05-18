import os
import json
from datetime import datetime
import vertexai # type: ignore
from vertexai.generative_models import GenerativeModel, GenerationConfig # type: ignore
PROJECT_ID = os.getenv("GCP_PROJECT_ID", "ai-seekho-hackathon-496416")
LOCATION = os.getenv("GCP_LOCATION", "us-central1")

class SupplyChainAgent:
    def __init__(self):
        self.initialized = False
        print("SupplyChainAgent: Using Gemini API (local mode)")

    def analyze_disparities(self, inventory_data: list, complaints_data: list) -> dict:
        return self._fallback_analysis(inventory_data, complaints_data)

        inventory_text = json.dumps(inventory_data, indent=2)
        complaints_text = json.dumps(complaints_data, indent=2)

        prompt = f"""You are an expert supply chain analyst for Pakistan pharmaceutical sector.

Analyze the following WAREHOUSE INVENTORY DATA and CUSTOMER COMPLAINTS DATA.
Detect mismatches where warehouse shows high stock but complaints indicate 
real shortages, stockouts, delivery delays, or unavailability on the ground.

WAREHOUSE INVENTORY DATA:
{inventory_text}

CUSTOMER COMPLAINTS DATA:
{complaints_text}

Your task:
1. Find every SKU where warehouse quantity seems high but complaints say shortage
2. Identify location-specific stockouts even if overall quantity looks sufficient
3. Flag any SKU with multiple high-severity complaints as CRITICAL
4. Flag any SKU with stale data (last_updated more than 2 days ago) as WARNING
5. Flag normal situations as LOW

Respond with ONLY a valid JSON object. No markdown. No explanation. 
Follow this exact schema:
{{
  "alerts": [
    {{
      "sku": "string",
      "item_name": "string", 
      "risk_level": "CRITICAL",
      "reason": "string explaining the mismatch in detail",
      "location": "string - specific Karachi area or General"
    }}
  ],
  "summary": "one sentence overall situation summary",
  "analysis_timestamp": "{datetime.utcnow().isoformat()}",
  "total_skus_analyzed": {len(inventory_data)},
  "critical_count": 0,
  "warning_count": 0
}}

Fill critical_count and warning_count with actual counts from your alerts array.
"""

        try:
            generation_config = GenerationConfig(
                response_mime_type="application/json",
                temperature=0.1,
                max_output_tokens=2048
            )
            response = self.model.generate_content(
                prompt,
                generation_config=generation_config
            )
            result = json.loads(response.text)
            return result
        except json.JSONDecodeError as e:
            return {"error": f"JSON parse failed: {e}", "raw": response.text}
        except Exception as e:
            return {"error": f"Vertex AI call failed: {e}"}

    def _fallback_analysis(self, inventory_data: list, complaints_data: list) -> dict:
        import google.generativeai as genai
        genai.configure(api_key=os.getenv("GEMINI_API_KEY"))

        inventory_text = json.dumps(inventory_data, indent=2)
        complaints_text = json.dumps(complaints_data, indent=2)

        prompt = f"""You are an expert urban crisis management analyst for Karachi, Pakistan.

Analyze CRISIS FIELD REPORTS and EMERGENCY RESOURCE INVENTORY. 
Find mismatches where warehouses or depots show available stock 
but field reports indicate critical shortages or inaccessibility on the ground.
This covers: flood relief supplies, rescue equipment, emergency medical kits,
food packs, clean water, and evacuation resources.

RESOURCE INVENTORY:
{inventory_text}

FIELD CRISIS REPORTS:
{complaints_text}

Rules:
- Resource with 2+ critical field reports = CRITICAL
- Resource depleted below 25 percent of threshold = CRITICAL  
- Resource with stale data over 12 hours = WARNING
- Inaccessible depot due to flooding or blockage = CRITICAL

Respond with ONLY valid JSON, no markdown:
{{
  "alerts": [
    {{
      "sku": "string",
      "item_name": "string",
      "risk_level": "CRITICAL",
      "reason": "detailed explanation of the crisis mismatch",
      "location": "specific Karachi area"
    }}
  ],
  "summary": "one sentence urban crisis summary",
  "analysis_timestamp": "{datetime.utcnow().isoformat()}",
  "total_skus_analyzed": {len(inventory_data)},
  "critical_count": 0,
  "warning_count": 0
}}"""

        try:
            model = genai.GenerativeModel("gemini-2.5-flash")
            response = model.generate_content(prompt)
            text = response.text.strip()
            if text.startswith("```"):
                lines = text.split("\n")
                text = "\n".join(lines[1:-1])
            return json.loads(text)
        except Exception as e:
            return {
                "alerts": [],
                "error": str(e),
                "summary": "Analysis failed - check API keys",
                "analysis_timestamp": datetime.utcnow().isoformat(),
                "total_skus_analyzed": len(inventory_data),
                "critical_count": 0,
                "warning_count": 0
            }