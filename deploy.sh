#!/bin/bash

# Configuration
PROJECT_ID="" # Fill this in or input when running
REGION="asia-southeast1" # Default region, can be changed
SERVICE_NAME="numberniceic"
DB_INSTANCE_CONNECTION_NAME="" # e.g. project:region:instance

echo "--- NumberNiceIC Deployment Helper ---"

# 1. Check GCloud Login
if ! gcloud auth list --filter=status:ACTIVE --format="value(account)" | grep -q "@"; then
    echo "Please login to gcloud first:"
    gcloud auth login
fi

# 2. Get Project ID
if [ -z "$PROJECT_ID" ]; then
    current_project=$(gcloud config get-value project)
    read -p "Enter Google Cloud Project ID [$current_project]: " input_project
    PROJECT_ID="${input_project:-$current_project}"
fi
echo "Using Project: $PROJECT_ID"
gcloud config set project $PROJECT_ID

# 3. Build and Deploy to Cloud Run
echo "--- Deploying to Cloud Run ---"
read -p "Enter Cloud Run Service Name [$SERVICE_NAME]: " input_service
SERVICE_NAME="${input_service:-$SERVICE_NAME}"

gcloud run deploy $SERVICE_NAME \
    --source . \
    --region $REGION \
    --allow-unauthenticated \
    --set-env-vars="DB_HOST=/cloudsql/$DB_INSTANCE_CONNECTION_NAME" # Placeholder, user needs to config env

# 4. Update Database
echo "--- Updating Database ---"
# Check if cloud-sql-proxy is installed
if ! command -v cloud_sql_proxy &> /dev/null; then
    echo "cloud_sql_proxy not found. Skipping auto-migration."
    echo "Please run the migration manually using 'go run cmd/migrate/main.go' connected to your production DB."
else
    if [ -z "$DB_INSTANCE_CONNECTION_NAME" ]; then
        # Try to detect automatically (might find nothing if 0 items)
        detected_conn=$(gcloud sql instances list --format="value(connectionName)" | head -n 1)
        if [ -n "$detected_conn" ]; then
             DB_INSTANCE_CONNECTION_NAME="$detected_conn"
             echo "Detected Cloud SQL Instance: $DB_INSTANCE_CONNECTION_NAME"
        else
             read -p "Enter Cloud SQL Instance Connection Name (project:region:instance): " input_conn
             DB_INSTANCE_CONNECTION_NAME="$input_conn"
        fi
    fi
    
    echo "Starting Cloud SQL Proxy..."
    # Check current dir for binary first, then PATH
    if [ -f "./cloud_sql_proxy" ]; then
        ./cloud_sql_proxy -instances=$DB_INSTANCE_CONNECTION_NAME=tcp:5433 &
    else
        cloud_sql_proxy -instances=$DB_INSTANCE_CONNECTION_NAME=tcp:5433 &
    fi
    
    PROXY_PID=$!
    sleep 5 # Wait for proxy
    
    echo "Running Migration..."
    # Run migration using local go script pointing to proxy port
    DB_HOST=127.0.0.1 DB_PORT=5433 go run cmd/migrate/main.go
    
    kill $PROXY_PID
fi

echo "Deployment Complete!"
