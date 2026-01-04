#!/bin/bash

# Configuration
SERVER_IP="43.228.85.200"
SERVER_USER="tayap"
APP_NAME="numberniceic"
REMOTE_DIR="/home/$SERVER_USER/$APP_NAME"

echo "--- Deploying to Dedicated Server ($SERVER_IP) ---"

# 1. Build for Linux
echo "Building Go binary for Linux..."
GOOS=linux GOARCH=amd64 go build -o numbernice-linux main.go
if [ $? -ne 0 ]; then
    echo "Build failed!"
    exit 1
fi

# 2. Transfer Files (Using scp instead of gcloud)
echo "Stopping service and uploading files..."
# Need sshpass for password auth in script, or assume key auth setup.
# If key auth is not set up, user will need to enter password multiple times or use sshpass
# Here we will assume user might have to enter password or has key setup.
# Ideally we should use ssh keys.

# Stop Service
ssh $SERVER_USER@$SERVER_IP "sudo systemctl stop numberniceic"

# Create directory
ssh $SERVER_USER@$SERVER_IP "mkdir -p $REMOTE_DIR/migrations"

# Upload Binary
scp numbernice-linux $SERVER_USER@$SERVER_IP:$REMOTE_DIR/numbernice-linux

# Upload Migrations
scp migrations/*.sql $SERVER_USER@$SERVER_IP:$REMOTE_DIR/migrations/

# Upload Static Files
echo "Uploading CSS and Assets..."
scp -r static/css $SERVER_USER@$SERVER_IP:$REMOTE_DIR/static/ 
# scp -r static $SERVER_USER@$SERVER_IP:$REMOTE_DIR/ # Uncomment if full static upload needed

# Upload Templates
scp -r views $SERVER_USER@$SERVER_IP:$REMOTE_DIR/

# Upload .env
scp .env.production $SERVER_USER@$SERVER_IP:$REMOTE_DIR/.env

# Build local migration runner
echo "Building Migration Tool for Linux..."
GOOS=linux GOARCH=amd64 go build -o run_migration-linux cmd/migrate/main.go
scp run_migration-linux $SERVER_USER@$SERVER_IP:$REMOTE_DIR/

# 3. Apply Changes & Restart
echo "Applying changes on server..."
ssh $SERVER_USER@$SERVER_IP "cd $REMOTE_DIR && chmod +x numbernice-linux run_migration-linux && mv numbernice-linux numberniceic && ./run_migration-linux && echo 'Restarting Service...' && sudo systemctl restart numberniceic && sudo systemctl status numberniceic --no-pager"

echo "Deployment to Server Complete!"
