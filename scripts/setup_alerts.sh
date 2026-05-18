#!/bin/bash

# ==============================================================================
# OptiFlow Alerts Setup Script
# Configures Pub/Sub topic and deploys the alert handler Cloud Function.
# ==============================================================================

# 1. Configuration
TOPIC_NAME="supply-chain-alerts"
FUNCTION_NAME="supply-chain-alert-handler"
REGION="asia-south1"
RUNTIME="python311"

echo "🔔 Setting up Supply Chain Alerts System..."

# 2. Create Pub/Sub Topic
if ! gcloud pubsub topics list --filter="name.scope(topic):$TOPIC_NAME" --format="value(name)" | grep -q "$TOPIC_NAME"; then
    echo "Creating Pub/Sub topic: $TOPIC_NAME..."
    gcloud pubsub topics create $TOPIC_NAME
else
    echo "✅ Pub/Sub topic '$TOPIC_NAME' already exists."
fi

# 3. Deploy Cloud Function (2nd Gen)
echo "🚀 Deploying Cloud Function: $FUNCTION_NAME..."

gcloud functions deploy $FUNCTION_NAME \
    --gen2 \
    --runtime=$RUNTIME \
    --region=$REGION \
    --source=./functions/alert_handler \
    --entry-point=handle_supply_chain_alert \
    --trigger-topic=$TOPIC_NAME \
    --set-env-vars LOG_LEVEL=INFO

echo "----------------------------------------------------------------"
echo "✅ Alerts System Configured!"
echo "Topic: $TOPIC_NAME"
echo "Function: $FUNCTION_NAME"
echo "----------------------------------------------------------------"
