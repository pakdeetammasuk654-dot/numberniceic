#!/bin/bash
SERVER_INSTANCE="my-free-server"
ZONE="us-central1-a"
REMOTE_APP_DIR="/home/tayap/apps/numberniceic"
BACKUP_FILENAME="backup_$(date +%Y%m%d_%H%M%S).sql"
REMOTE_BACKUP_PATH="/tmp/$BACKUP_FILENAME"

echo "Creating database backup on remote server..."
gcloud compute ssh $SERVER_INSTANCE --zone=$ZONE --command="
    set -a
    source $REMOTE_APP_DIR/.env
    set +a
    # Default to localhost if DB_HOST is not set or empty
    if [ -z \"\$DB_HOST\" ]; then DB_HOST=localhost; fi
    if [ -z \"\$DB_PORT\" ]; then DB_PORT=5432; fi
    
    echo \"Dumping database \$DB_NAME from \$DB_HOST...\"
    PGPASSWORD=\$DB_PASSWORD pg_dump -U \$DB_USER -h \$DB_HOST -p \$DB_PORT \$DB_NAME > $REMOTE_BACKUP_PATH
"

if [ $? -eq 0 ]; then
    echo "Backup created successfully at $REMOTE_BACKUP_PATH"
    echo "Downloading backup to local machine..."
    gcloud compute scp $SERVER_INSTANCE:$REMOTE_BACKUP_PATH ./$BACKUP_FILENAME --zone=$ZONE
    
    if [ $? -eq 0 ]; then
        echo "Cleaning up remote backup file..."
        gcloud compute ssh $SERVER_INSTANCE --zone=$ZONE --command="rm $REMOTE_BACKUP_PATH"
        echo "Backup saved to $(pwd)/$BACKUP_FILENAME"
    else
        echo "Failed to download backup."
    fi
else
    echo "Failed to create backup on remote server. Please check if pg_dump is installed and credentials are correct."
    exit 1
fi
