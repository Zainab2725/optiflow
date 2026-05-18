import base64
import json
import functions_framework # type: ignore

@functions_framework.http
def supply_chain_alert(request):
    try:
        envelope = request.get_json(silent=True)
        if not envelope:
            return "Bad Request: no JSON body", 400

        pubsub_message = envelope.get("message", {})
        data_b64 = pubsub_message.get("data", "")

        if not data_b64:
            return "Bad Request: no data field", 400

        data_bytes = base64.b64decode(data_b64)
        alert = json.loads(data_bytes.decode("utf-8"))

        sku = alert.get("sku", "UNKNOWN")
        item_name = alert.get("item_name", "Unknown Item")
        location = alert.get("location", "Unknown Location")
        reason = alert.get("reason", "No reason provided")
        risk_level = alert.get("risk_level", "UNKNOWN")

        log_message = (
            f"CRITICAL SUPPLY GAP DETECTED | "
            f"SKU: {sku} | "
            f"Item: {item_name} | "
            f"Location: {location} | "
            f"Risk: {risk_level} | "
            f"Reason: {reason}"
        )
        print(log_message)

        return {"status": "processed", "sku": sku, "risk_level": risk_level}, 200

    except (ValueError, KeyError, json.JSONDecodeError) as e:
        print(f"Alert processing error: {e}")
        return f"Processing error: {e}", 500
