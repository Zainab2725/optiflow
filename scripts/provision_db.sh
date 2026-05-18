#!/bin/bash

# ==============================================================================
# OptiFlow Cloud SQL Provisioning Script
# Region: asia-south1 (Mumbai) | Database: PostgreSQL 15
# ==============================================================================

# Exit on error
set -e

# --- Configuration ---
INSTANCE_NAME="optiflow-postgresql"
DB_NAME="optiflow"
REGION="asia-south1"
NETWORK="default" # The VPC network to connect to
PROJECT_ID=$(gcloud config get-value project)

echo "----------------------------------------------------------------"
echo "🚀 Initializing GCP Infrastructure for OptiFlow"
echo "Project ID: $PROJECT_ID"
echo "Instance:   $INSTANCE_NAME"
echo "Region:     $REGION"
echo "----------------------------------------------------------------"

# 1. Enable Google Cloud APIs
echo "🔧 Step 1: Enabling necessary APIs..."
gcloud services enable sqladmin.googleapis.com \
                       servicenetworking.googleapis.com \
                       compute.googleapis.com

# 2. Configure Private Service Access (PSA)
# PSA allows the Cloud SQL instance to communicate with your VPC via a private IP.
echo "🌐 Step 2: Configuring Private Service Access..."

# Reserve an internal IP range for Google services
# We check if the address already exists to avoid errors
if ! gcloud compute addresses list --filter="name=optiflow-psa-range" --format="value(name)" | grep -q "optiflow-psa-range"; then
    echo "Creating IP range reservation..."
    gcloud compute addresses create optiflow-psa-range \
        --global \
        --purpose=VPC_PEERING \
        --prefix-length=16 \
        --description="Peering range for OptiFlow Cloud SQL" \
        --network=$NETWORK
else
    echo "✅ IP range reservation already exists."
fi

# Create the private connection
echo "Connecting VPC to service producer..."
gcloud services vpc-peerings connect \
    --service=servicenetworking.googleapis.com \
    --ranges=optiflow-psa-range \
    --network=$NETWORK \
    --project=$PROJECT_ID

# 3. Create the Cloud SQL Instance
echo "🏗️ Step 3: Provisioning PostgreSQL 15 Instance..."
echo "(This may take several minutes...)"

gcloud sql instances create $INSTANCE_NAME \
    --database-version=POSTGRES_15 \
    --region=$REGION \
    --cpu=2 \
    --memory=7680MB \
    --no-assign-ip \
    --network=projects/$PROJECT_ID/global/networks/$NETWORK \
    --availability-type=ZONAL \
    --storage-type=SSD \
    --storage-size=10GB

# 4. Create the Database
echo "🗄️ Step 4: Creating database '$DB_NAME'..."
gcloud sql databases create $DB_NAME --instance=$INSTANCE_NAME

# 5. Schema Initialization
echo "📋 Step 5: Preparing Schema Initialization..."

SQL_QUERY="CREATE TABLE IF NOT EXISTS pharma_inventory (
    sku VARCHAR(50) PRIMARY KEY,
    item_name VARCHAR(255) NOT NULL,
    stock_level INTEGER DEFAULT 0,
    logistics_risk_score DECIMAL(3, 2)
);"

# Note: Since the instance has NO public IP, we cannot run SQL directly from 
# a local machine without the Cloud SQL Auth Proxy. 
# We recommend using the 'cloud-sql-python-connector' already in your requirements.txt.

echo "----------------------------------------------------------------"
echo "✅ SUCCESS: Infrastructure provisioned."
echo "----------------------------------------------------------------"
echo "Database Instance: $INSTANCE_NAME"
echo "Private IP only:   Enabled"
echo ""
echo "To initialize the table, run the following SQL command via the"
echo "Cloud SQL Auth Proxy or from a VM within the '$NETWORK' VPC:"
echo ""
echo "$SQL_QUERY"
echo "----------------------------------------------------------------"
