#!/bin/bash

# === CONFIGURATION ===

# DO NOT REMOVE: MacBook mapped folder (example)
# BACKUP_SOURCE_FOLDER="/Users/neoxr/storage_k8s_pods/"

# DO NOT REMOVE: Actual PVC location on VM
BACKUP_SOURCE_FOLDER="/var/lib/rancher/k3s/storage"

BACKUP_DESTINATION_FOLDER="."  # Current directory where script is run

TIMESTAMP=$(date +"%Y.%m.%d.%H.%M")
BACKUP_DIR="${BACKUP_DESTINATION_FOLDER}/backup.k8s.pvcs.${TIMESTAMP}"

mkdir -p "$BACKUP_DIR" || { echo "Fatal: Could not create $BACKUP_DIR"; exit 1; }
echo "Backup directory: $BACKUP_DIR"
echo "Source PVC folder: $BACKUP_SOURCE_FOLDER"

PVC_FOUND=0
BACKUP_FILES=()

# === FIRST PASS: BACKUP PVCs ===
for PVC_FULL_PATH in "$BACKUP_SOURCE_FOLDER"/pvc-*; do
    [ -d "$PVC_FULL_PATH" ] || continue
    PVC_FOUND=1

    PVC_FOLDER=$(basename "$PVC_FULL_PATH")
    GUID=$(echo "$PVC_FOLDER" | cut -d'_' -f1 | cut -d'-' -f2)
    SUFFIX=$(echo "$PVC_FOLDER" | cut -d'_' -f2- | tr '-' '.')
    BACKUP_FILE="backup.${TIMESTAMP}.${SUFFIX}--${GUID}.tgz"
    BACKUP_PATH="${BACKUP_DIR}/${BACKUP_FILE}"

    if tar -czpf "$BACKUP_PATH" -C "$BACKUP_SOURCE_FOLDER" "$PVC_FOLDER"; then
        echo "Backed up: $PVC_FOLDER -> $BACKUP_PATH"
        BACKUP_FILES+=("$BACKUP_PATH")
    else
        echo "Error: Failed to create archive for $PVC_FOLDER" >&2
    fi
done

if [ "$PVC_FOUND" -eq 0 ]; then
    echo "No PVC folders found in source: $BACKUP_SOURCE_FOLDER"
    exit 2
fi

echo
echo "=== SECOND PASS: INTEGRITY CHECKS ==="

INTEGRITY_PASS=1

REGEX="^backup\.[0-9]{4}\.[0-9]{2}\.[0-9]{2}\.[0-9]{2}\.[0-9]{2}\.[a-zA-Z0-9_.-]+--[a-f0-9]{8}\.tgz$"

for BACKUP_PATH in "${BACKUP_FILES[@]}"; do
    BACKUP_FILE=$(basename "$BACKUP_PATH")
    echo "Checking: $BACKUP_FILE"

    # Check file is non-empty
    if [ ! -s "$BACKUP_PATH" ]; then
        echo "  [FAIL] File is empty!"
        INTEGRITY_PASS=0
        continue
    fi

    # Check valid tar archive
    if ! tar -tzf "$BACKUP_PATH" >/dev/null 2>&1; then
        echo "  [FAIL] Not a valid tar archive!"
        INTEGRITY_PASS=0
        continue
    fi

    # Check filename pattern
    if [[ ! "$BACKUP_FILE" =~ $REGEX ]]; then
        echo "  [FAIL] Filename does not match required pattern!"
        INTEGRITY_PASS=0
        continue
    fi

    echo "  [PASS] Integrity checks passed."
done

if [ "$INTEGRITY_PASS" -eq 1 ]; then
    echo
    echo "All backup files passed integrity checks."
else
    echo
    echo "Some backup files FAILED integrity checks. Please review the output above."
    exit 3
fi

echo
echo "Backup and verification complete: $BACKUP_DIR"