import json
import sys
import os
from datetime import datetime

def is_gcp_configured() -> bool:
    if os.getenv("GOOGLE_APPLICATION_CREDENTIALS"):
        return True
    # Check default credential paths
    appdata = os.getenv("APPDATA")
    if appdata:
        if os.path.exists(os.path.join(appdata, "gcloud", "application_default_credentials.json")):
            return True
    home = os.getenv("HOME") or os.getenv("USERPROFILE")
    if home:
        if os.path.exists(os.path.join(home, ".config", "gcloud", "application_default_credentials.json")):
            return True
    return False

import threading

def publish_to_pubsub(event_data: dict) -> tuple:
    fallback_id = f"LOCAL-{datetime.utcnow().strftime('%H%M%S')}"
    
    if not is_gcp_configured():
        print(f"[PubSub Bypass] Credentials not found. Local fallback ID: {fallback_id}", file=sys.stdout)
        return False, fallback_id

    # Spin up a background daemon thread so it NEVER blocks the main FastAPI request thread.
    def _async_publish():
        try:
            from google.cloud import pubsub_v1
            project_id = os.getenv(
                "GCP_PROJECT_ID", 
                "ai-seekho-hackathon-496416"
            )
            topic_id = "supply-chain-alerts"
            topic_path = f"projects/{project_id}/topics/{topic_id}"
            
            publisher = pubsub_v1.PublisherClient()
            message_bytes = json.dumps(event_data).encode("utf-8")
            future = publisher.publish(topic_path, message_bytes)
            # We can wait for a timeout on the background thread without blocking the client
            msg_id = future.result(timeout=5)
            print(f"[PubSub Success] Message published to GCP. ID: {msg_id}", file=sys.stdout)
        except Exception as e:
            print(f"[Background PubSub Error] Failed to publish: {e}", file=sys.stderr)

    threading.Thread(target=_async_publish, daemon=True).start()
    
    # Return immediately to avoid blocking client UI
    return True, f"ASYNC-{fallback_id}"
