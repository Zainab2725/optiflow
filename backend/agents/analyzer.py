import vertexai # type: ignore
from vertexai.generative_models import GenerativeModel, GenerationConfig # type: ignore
import json
import os

class OptiFlowAnalyzer:
    """
    Analyzes supply chain data using Vertex AI's Gemini 1.5 Pro.
    Identifies contradictions between structured warehouse data and unstructured feedback.
    """
    
    def __init__(self, project_id: str = None, location: str = "us-central1"):
        # Initialize Vertex AI with project info
        self.project_id = project_id or os.getenv("GOOGLE_CLOUD_PROJECT")
        self.location = location
        
        vertexai.init(project=self.project_id, location=self.location)
        
        # Load Gemini 1.5 Pro
        self.model = GenerativeModel("gemini-1.5-pro")

    def identify_contradictions(self, warehouse_csv: str, user_feedback: list[str]) -> dict:
        """
        Prompts Gemini to find discrepancies between CSV stock levels and user reports.
        """
        
        prompt = f"""
        You are a Supply Chain Intelligence Agent. Your task is to identify "Supply Chain Contradictions."
        
        A contradiction exists when structured warehouse data (CSV) shows one reality, 
        but unstructured user feedback (complaints/reports) indicates another.

        ### DATA INPUTS:
        
        WAREHOUSE INVENTORY (CSV):
        {warehouse_csv}

        USER FEEDBACK STRINGS:
        {user_feedback}

        ### INSTRUCTIONS:
        1. Compare stock levels in the CSV with reported issues in the feedback.
        2. Flag items where CSV shows "High Stock" but feedback says "Shortage/Stockout".
        3. Flag items where CSV shows "Low Stock" but feedback says "Excess/Expiry Risk".
        4. Return the results in a STICTLY formatted JSON object.

        ### OUTPUT FORMAT (JSON):
        {{
            "contradictions": [
                {{
                    "sku": "SKU_ID",
                    "item_name": "Name of the drug",
                    "conflict_type": "Shortage Paradox | Surplus Mismatch",
                    "description": "Clear explanation of the contradiction",
                    "severity": "high | medium | low"
                }}
            ],
            "analysis_metadata": {{
                "timestamp": "ISO_8601",
                "risk_level_summary": "Summary string"
            }}
        }}
        """

        # Ensure structured output using response_mime_type
        response = self.model.generate_content(
            prompt,
            generation_config=GenerationConfig(
                response_mime_type="application/json",
                temperature=0.2
            )
        )

        try:
            return json.loads(response.text)
        except json.JSONDecodeError:
            return {"error": "Failed to parse Gemini response as JSON", "raw": response.text}
