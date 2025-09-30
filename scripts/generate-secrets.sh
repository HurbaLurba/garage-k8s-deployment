#!/bin/bash
# Generate Garage Security Tokens
# Run this script to generate secure random tokens for garage.toml configuration

set -e

echo "==================================="
echo "Garage Security Token Generator"
echo "==================================="
echo ""

echo "Generating RPC Secret (64 character hex string)..."
RPC_SECRET=$(openssl rand -hex 32)
echo "RPC_SECRET=$RPC_SECRET"
echo ""

echo "Generating Admin Token (32 character hex string)..."
ADMIN_TOKEN=$(openssl rand -hex 16)
echo "ADMIN_TOKEN=$ADMIN_TOKEN"
echo ""

echo "Generating Metrics Token (32 character hex string)..."
METRICS_TOKEN=$(openssl rand -hex 16)
echo "METRICS_TOKEN=$METRICS_TOKEN"
echo ""

echo "==================================="
echo "NEXT STEPS:"
echo "==================================="
echo "1. Copy the tokens above"
echo "2. Edit manifests/01-configmap-garage-toml.yaml"
echo "3. Replace the following placeholders:"
echo "   - rpc_secret = \"$RPC_SECRET\""
echo "   - admin_token = \"$ADMIN_TOKEN\""
echo "   - metrics_token = \"$METRICS_TOKEN\""
echo ""
echo "4. Update health probes in manifests/02-deployment.yaml:"
echo "   - Replace 'CHANGE_ME_TO_RANDOM_ADMIN_TOKEN' with: $ADMIN_TOKEN"
echo ""
echo "SECURITY NOTE: Keep these tokens secure and never commit to version control!"
echo "==================================="
