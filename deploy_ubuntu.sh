#!/bin/bash

# Configuration
SERVER_IP="34.44.200.128" # Found from gcloud
SERVER_USER="tayap" # Making a guess based on local user, script will prompt if wrong/key missing usually, or user can edit.
APP_NAME="numberniceic"
REMOTE_DIR="/home/$SERVER_USER/apps/$APP_NAME"

echo "--- Deploying to Ubuntu Server ($SERVER_IP) ---"

# 1. Build for Linux
echo "Building Go binary for Linux..."
GOOS=linux GOARCH=amd64 go build -o numbernice-linux main.go
if [ $? -ne 0 ]; then
    echo "Build failed!"
    exit 1
fi

# 2. Transfer Files
echo "Stopping service and uploading files..."
INSTANCE_NAME="my-free-server"
ZONE="us-central1-a"

# Stop service to unlock binary
gcloud compute ssh $INSTANCE_NAME --zone=$ZONE --command="sudo systemctl stop numberniceic"

# Create directory
gcloud compute ssh $INSTANCE_NAME --zone=$ZONE --command="mkdir -p $REMOTE_DIR/migrations"

# Upload Binary
gcloud compute scp numbernice-linux $INSTANCE_NAME:$REMOTE_DIR/numbernice-linux --zone=$ZONE

# Upload Migrations
gcloud compute scp migrations/*.sql $INSTANCE_NAME:$REMOTE_DIR/migrations/ --zone=$ZONE

# Upload Static Files (Optimized: Skip heavy images, update CSS/JS/Icons)
# gcloud compute scp --recurse static $INSTANCE_NAME:$REMOTE_DIR/ --zone=$ZONE
echo "Uploading CSS only (skipping images for speed)..."
gcloud compute scp --recurse static/css $INSTANCE_NAME:$REMOTE_DIR/static/ --zone=$ZONE --force-key-file-overwrite

# Upload Templates
gcloud compute scp --recurse views $INSTANCE_NAME:$REMOTE_DIR/ --zone=$ZONE

# Upload .env (Crucial for DB connection)
gcloud compute scp .env $INSTANCE_NAME:$REMOTE_DIR/ --zone=$ZONE

# Build local migration runner
GOOS=linux GOARCH=amd64 go build -o run_migration-linux run_migration.go
gcloud compute scp run_migration-linux $INSTANCE_NAME:$REMOTE_DIR/ --zone=$ZONE

# 3. Apply Changes & Restart
echo "Applying changes on server..."
gcloud compute ssh $INSTANCE_NAME --zone=$ZONE --command="cd $REMOTE_DIR && chmod +x numbernice-linux run_migration-linux && ./run_migration-linux && echo 'Restarting Service...' && sudo systemctl restart numberniceic && sudo systemctl status numberniceic --no-pager"

echo "Deployment to Ubuntu Server Complete!"

echo "Deployment to Ubuntu Server Complete!"
