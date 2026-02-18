#!/bin/bash

# ==============================
# CONFIGURATION
# ==============================
REMOTE_USER="root"
REMOTE_HOST="45.77.31.190"
VOLUMES=("ipfs_data" "ipfs_staging" "ipfs_volume")
LOCAL_BACKUP_BASE="$HOME/backup-cyrene/ipfs"
RETENTION_DAYS=7
PARALLEL_JOBS=3

# ==============================
# AUTO GENERATED VALUES
# ==============================
TIMESTAMP=$(date +"%Y-%m-%d_%H-%M-%S")

echo "🚀 Starting parallel Docker volume backup..."
echo "Timestamp: $TIMESTAMP"
echo "---------------------------------------"

backup_volume() {

    VOLUME=$1
    LOCAL_VOLUME_DIR="${LOCAL_BACKUP_BASE}/${VOLUME}"
    mkdir -p "${LOCAL_VOLUME_DIR}"

    BACKUP_FILE="${VOLUME}_${TIMESTAMP}.tar.gz"
    REMOTE_TMP="/tmp/${BACKUP_FILE}"

    echo "🔍 [$VOLUME] Inspecting..."

    REMOTE_VOLUME_PATH=$(ssh ${REMOTE_USER}@${REMOTE_HOST} \
      "docker volume inspect ${VOLUME} -f '{{ .Mountpoint }}'")

    if [ -z "$REMOTE_VOLUME_PATH" ]; then
        echo "❌ [$VOLUME] Volume not found"
        return
    fi

    echo "📦 [$VOLUME] Creating archive..."
    ssh ${REMOTE_USER}@${REMOTE_HOST} \
      "tar -czf ${REMOTE_TMP} -C ${REMOTE_VOLUME_PATH} ." || return

    echo "⬇️ [$VOLUME] Downloading..."
    scp ${REMOTE_USER}@${REMOTE_HOST}:${REMOTE_TMP} \
      "${LOCAL_VOLUME_DIR}/${BACKUP_FILE}" || return

    ssh ${REMOTE_USER}@${REMOTE_HOST} "rm -f ${REMOTE_TMP}"

    echo "🧹 [$VOLUME] Removing backups older than ${RETENTION_DAYS} days..."

    find "${LOCAL_VOLUME_DIR}" -type f -name "*.tar.gz" -mtime +${RETENTION_DAYS} -delete

    echo "✅ [$VOLUME] Done"
}

# ==============================
# PARALLEL EXECUTION
# ==============================

for VOLUME in "${VOLUMES[@]}"; do
    backup_volume "$VOLUME" &

    # Limit parallel jobs
    while [ "$(jobs -r | wc -l)" -ge "$PARALLEL_JOBS" ]; do
        sleep 1
    done
done

wait

echo "🎉 All backups completed!"