#!/bin/bash
SERVER_IP="43.228.85.200"
SERVER_USER="tayap"
SSH_PASS="IntelliP24.X"
APP_NAME="numberniceic"
REMOTE_DIR="/home/$SERVER_USER/$APP_NAME"
SSHPASS="sshpass -p $SSH_PASS"
SSH_CMD="$SSHPASS ssh -o StrictHostKeyChecking=no"
SCP_CMD="$SSHPASS scp -o StrictHostKeyChecking=no"

echo "Step 1: Building binaries for Linux..."
~/go/bin/templ generate
GOOS=linux GOARCH=amd64 go build -o numbernice-linux main.go
GOOS=linux GOARCH=amd64 go build -o run_migration-linux cmd/migrate/main.go

echo "Step 2: Stopping service..."
# Try to stop service, ignore failure if it doesn't exist yet
$SSH_CMD $SERVER_USER@$SERVER_IP "echo $SSH_PASS | sudo -S systemctl stop numberniceic || true"

echo "Step 3: Creating directories..."
$SSH_CMD $SERVER_USER@$SERVER_IP "mkdir -p $REMOTE_DIR/migrations $REMOTE_DIR/static/css $REMOTE_DIR/static/js $REMOTE_DIR/assets"

echo "Step 4: Uploading files using SCP..."
$SCP_CMD numbernice-linux $SERVER_USER@$SERVER_IP:$REMOTE_DIR/numbernice-linux
$SCP_CMD -r migrations/*.sql $SERVER_USER@$SERVER_IP:$REMOTE_DIR/migrations/
# Ensure static dirs exist locally before scp -r
if [ -d "static/css" ]; then
    $SCP_CMD -r static/css $SERVER_USER@$SERVER_IP:$REMOTE_DIR/static/
fi
if [ -d "static/js" ]; then
    $SCP_CMD -r static/js $SERVER_USER@$SERVER_IP:$REMOTE_DIR/static/
fi
if [ -d "static/images" ]; then
    $SCP_CMD -r static/images $SERVER_USER@$SERVER_IP:$REMOTE_DIR/static/
fi
if [ -d "assets" ]; then
    $SCP_CMD -r assets $SERVER_USER@$SERVER_IP:$REMOTE_DIR/
fi
$SCP_CMD static/favicon.* $SERVER_USER@$SERVER_IP:$REMOTE_DIR/static/
$SCP_CMD -r views $SERVER_USER@$SERVER_IP:$REMOTE_DIR/
$SCP_CMD .env.production $SERVER_USER@$SERVER_IP:$REMOTE_DIR/.env
$SCP_CMD run_migration-linux $SERVER_USER@$SERVER_IP:$REMOTE_DIR/

echo "Step 5: Setting permissions and restarting..."
$SSH_CMD $SERVER_USER@$SERVER_IP "cd $REMOTE_DIR && chmod +x numbernice-linux run_migration-linux && mv numbernice-linux numberniceic && ./run_migration-linux && echo $SSH_PASS | sudo -S systemctl restart numberniceic"

echo "Deployment finished."
