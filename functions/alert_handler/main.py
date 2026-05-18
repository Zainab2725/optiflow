import base64
import json
import functions_framework

@functions_framework.cloud_event
def handle_supply_chain_alert(cloud_event):
    """
    Background Cloud Function (2nd Gen) triggered by Pub/Sub.
    Parses supply chain alerts and logs a summary.
    """
    
    # The CloudEvent data payload contains the Pub/Sub message
    # Format: {"message": {"data": "BASE64_ENCODED_STRING", "attributes": {...}}}
    pubsub_data = cloud_event.data["message"]["data"]
    
    # Decode base64 to string
    decoded_message = base64.b64decode(pubsub_data).decode("utf-8")
    
    try:
        # Parse JSON payload
        alert = json.loads(decoded_message)
        
        # Log summary for Cloud Logging
        print("--- SUPPLY CHAIN ALERT RECEIVED ---")
        print(f"ID:       {alert.get('sku', 'UNKNOWN')}")
        print(f"ITEM:     {alert.get('item_name', 'N/A')}")
        print(f"TYPE:     {alert.get('conflict_type', 'General Alert')}")
        print(f"SEVERITY: {alert.get('severity', 'MEDIUM').upper()}")
        print(f"DESC:     {alert.get('description', 'No details provided.')}")
        print("-----------------------------------")
        
    except json.JSONDecodeError as e:
        print(f"❌ Error: Failed to parse alert message: {e}")
        print(f"Raw Content: {decoded_message}")
    except Exception as e:
        print(f"❌ Unexpected Error: {str(e)}")
