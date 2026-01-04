#!/bin/bash

# Configuration
SERVER_IP="43.228.85.200"
SERVER_USER="tayap"
APP_NAME="numberniceic"
REMOTE_DIR="/home/$SERVER_USER/$APP_NAME"
SSH_SOCKET="/Users/tayap/.ssh/control-${SERVER_IP}-tayap"
SSH_OPTS="-o ControlPath=$SSH_SOCKET"

SERVER_PASS="IntelliP24.X"

echo "--- Deploying to Dedicated Server ($SERVER_IP) with Multiplexing ---"

# 1. Build for Linux
echo "Building Go binary for Linux..."
GOOS=linux GOARCH=amd64 go build -o numbernice-linux main.go
if [ $? -ne 0 ]; then
    echo "Build failed!"
    exit 1
fi

# 2. Transfer Files
echo "Stopping service and uploading files..."

# Stop Service
ssh $SSH_OPTS $SERVER_USER@$SERVER_IP "echo '$SERVER_PASS' | sudo -S systemctl stop numberniceic"

# Create directory
ssh $SSH_OPTS $SERVER_USER@$SERVER_IP "mkdir -p $REMOTE_DIR/migrations"

# Upload Binary
scp $SSH_OPTS numbernice-linux $SERVER_USER@$SERVER_IP:$REMOTE_DIR/numbernice-linux

# Upload Migrations
scp $SSH_OPTS migrations/*.sql $SERVER_USER@$SERVER_IP:$REMOTE_DIR/migrations/

# Upload Static Files
echo "Uploading CSS and Assets..."
scp $SSH_OPTS -r static/css $SERVER_USER@$SERVER_IP:$REMOTE_DIR/static/



# Upload .env
scp $SSH_OPTS .env.production $SERVER_USER@$SERVER_IP:$REMOTE_DIR/.env

# Build local migration runner
echo "Building Migration Tool for Linux..."
GOOS=linux GOARCH=amd64 go build -o run_migration-linux cmd/migrate/main.go
scp $SSH_OPTS run_migration-linux $SERVER_USER@$SERVER_IP:$REMOTE_DIR/

# 3. Apply Changes & Restart
echo "Applying changes on server..."
ssh $SSH_OPTS $SERVER_USER@$SERVER_IP "cd $REMOTE_DIR && rm -rf views && chmod +x numbernice-linux run_migration-linux && mv numbernice-linux numberniceic && ./run_migration-linux && echo 'Restarting Service...' && echo '$SERVER_PASS' | sudo -S systemctl restart numberniceic && echo '$SERVER_PASS' | sudo -S systemctl status numberniceic --no-pager"

echo "Deployment to Server Complete!"
