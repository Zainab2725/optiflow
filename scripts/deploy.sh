#!/bin/bash

# ==============================================================================
# OptiFlow Cloud Run Deployment Script
# This script builds the container and deploys it to Cloud Run with SQL Proxy.
# ==============================================================================

# 1. Configuration
SERVICE_NAME="optiflow-backend"
REGION="asia-south1"
PROJECT_ID=$(gcloud config get-value project)

# Format: project:region:instance
INSTANCE_CONNECTION_NAME="$PROJECT_ID:$REGION:optiflow-postgresql"

# 2. Deployment
echo "🚀 Deploying OptiFlow Backend to Cloud Run..."
echo "Project: $PROJECT_ID"
echo "Region:  $REGION"
echo "SQL:     $INSTANCE_CONNECTION_NAME"

gcloud run deploy $SERVICE_NAME \
    --source . \
    --region $REGION \
    --platform managed \
    --allow-unauthenticated \
    --add-cloudsql-instances $INSTANCE_CONNECTION_NAME \
    --set-env-vars DB_USER="postgres" \
    --set-env-vars DB_PASS="REPLACE_WITH_YOUR_DB_PASSWORD" \
    --set-env-vars DB_NAME="optiflow" \
    --set-env-vars INSTANCE_CONNECTION_NAME="$INSTANCE_CONNECTION_NAME" \
    --timeout 300 \
    --memory 1Gi \
    --cpu 1

echo "----------------------------------------------------------------"
echo "✅ Deployment initiated!"
echo "Service URL will be displayed above once the process completes."
echo "----------------------------------------------------------------"
