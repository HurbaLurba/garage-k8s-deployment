#!/bin/bash
# Setup Garage Storage Directories on Worker Node
# This script must be run ON THE WORKER NODE that will host Garage storage
# Usage: ./setup-worker-node-storage.sh [storage_path]

set -e

# Default storage path, can be overridden as first argument
STORAGE_PATH="${1:-/mnt/storage-data/garage}"

echo "==================================="
echo "Garage Storage Directory Setup"
echo "==================================="
echo "Storage Path: $STORAGE_PATH"
echo ""

# Create directory structure
echo "Creating directory structure..."
sudo mkdir -p "$STORAGE_PATH/data"
sudo mkdir -p "$STORAGE_PATH/meta"
sudo mkdir -p "$STORAGE_PATH/app"

# Set permissions (755 allows read/execute for all, write for owner)
echo "Setting permissions (755)..."
sudo chmod -R 755 "$STORAGE_PATH"

# Verify creation
echo ""
echo "Verifying directory structure..."
ls -lah "$STORAGE_PATH"

echo ""
echo "==================================="
echo "✓ Storage directories created successfully!"
echo "==================================="
echo "Directory structure:"
echo "  $STORAGE_PATH/data  - Object data storage"
echo "  $STORAGE_PATH/meta  - Metadata database (LMDB)"
echo "  $STORAGE_PATH/app   - Application files"
echo ""
echo "NEXT STEPS:"
echo "1. Update manifests/02-deployment.yaml nodeSelector with this node's hostname"
echo "2. Verify hostPath volumes in deployment point to: $STORAGE_PATH"
echo "3. Deploy to Kubernetes: kubectl apply -f manifests/"
echo "==================================="
