import json
import sys
import os
from datetime import datetime

def publish_to_pubsub(event_data: dict) -> tuple:
    project_id = os.getenv(
        "GCP_PROJECT_ID", 
        "ai-seekho-hackathon-496416"
    )
    topic_id = "supply-chain-alerts"
    topic_path = f"projects/{project_id}/topics/{topic_id}"
    
    try:
        from google.cloud import pubsub_v1
        publisher = pubsub_v1.PublisherClient()
        message_bytes = json.dumps(event_data).encode("utf-8")
        future = publisher.publish(topic_path, message_bytes)
        message_id = future.result(timeout=10)
        return True, message_id
    except Exception as e:
        # Safe local fallback - never crash demo
        fallback_id = f"LOCAL-{datetime.utcnow().strftime('%H%M%S')}"
        print(
            f"[PubSub Fallback] Event logged locally. "
            f"ID: {fallback_id} | "
            f"Type: {event_data.get('event_type')} | "
            f"Org: {event_data.get('org_id')}",
            file=sys.stdout
        )
        return False, fallback_id
