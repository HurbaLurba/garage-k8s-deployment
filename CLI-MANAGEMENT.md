# Garage S3 Storage - CLI Management Guide

This guide covers **kubectl-only** management of Garage S3 storage. All commands run directly against the Kubernetes cluster without requiring external tools.

## Table of Contents
- [Prerequisites](#prerequisites)
- [CLI Access](#cli-access)
- [Bucket Management](#bucket-management)
- [User & Key Management](#user--key-management)
- [Permission Management](#permission-management)
- [Common Workflows](#common-workflows)
- [Monitoring & Troubleshooting](#monitoring--troubleshooting)

---

## Prerequisites

- Kubernetes cluster with Garage deployed
- `kubectl` configured with cluster access
- Garage deployment running in `garage-storage` namespace

**Verify deployment is running:**
```bash
kubectl get pods -n garage-storage
```

Expected output:
```
NAME                                READY   STATUS    RESTARTS   AGE
garage-s3-storage-xxxxxxxxxx-xxxxx   1/1     Running   0          10m
```

---

## CLI Access

All Garage CLI commands run via `kubectl exec` against the running pod.

### Basic Command Pattern

```bash
kubectl exec -n garage-storage deployment/garage-s3-storage -- /garage <command> [args]
```

### Create an Alias (Optional but Recommended)

**Linux/macOS/WSL:**
```bash
alias garage='kubectl exec -n garage-storage deployment/garage-s3-storage -- /garage'
```

**Windows PowerShell:**
```powershell
function garage { kubectl exec -n garage-storage deployment/garage-s3-storage -- /garage $args }
```

After setting up the alias, you can use `garage <command>` instead of the full kubectl exec line.

---

## Bucket Management

### List All Buckets

```bash
kubectl exec -n garage-storage deployment/garage-s3-storage -- /garage bucket list
```

### Create a New Bucket

```bash
kubectl exec -n garage-storage deployment/garage-s3-storage -- /garage bucket create my-bucket-name
```

### Get Bucket Information

```bash
kubectl exec -n garage-storage deployment/garage-s3-storage -- /garage bucket info my-bucket-name
```

### Delete a Bucket

⚠️ **WARNING:** Bucket must be empty before deletion!

```bash
kubectl exec -n garage-storage deployment/garage-s3-storage -- /garage bucket delete my-bucket-name
```

### Configure Bucket Quotas

Set maximum size (e.g., 100GB):
```bash
kubectl exec -n garage-storage deployment/garage-s3-storage -- /garage bucket quota my-bucket-name --size 100GB
```

Remove quota:
```bash
kubectl exec -n garage-storage deployment/garage-s3-storage -- /garage bucket quota my-bucket-name --no-quota
```

---

## User & Key Management

### List All Keys

```bash
kubectl exec -n garage-storage deployment/garage-s3-storage -- /garage key list
```

### Create a New API Key

```bash
kubectl exec -n garage-storage deployment/garage-s3-storage -- /garage key create my-user-key
```

Output example:
```
Key ID: GK1234567890abcdef
Secret Key: 1234567890abcdef1234567890abcdef1234567890abcdef
```

**⚠️ IMPORTANT:** Save the Secret Key immediately! It cannot be retrieved later.

### Create Key with Specific Name

```bash
kubectl exec -n garage-storage deployment/garage-s3-storage -- /garage key new --name "production-app"
```

### Get Key Information

```bash
kubectl exec -n garage-storage deployment/garage-s3-storage -- /garage key info GK1234567890abcdef
```

### Rename a Key

```bash
kubectl exec -n garage-storage deployment/garage-s3-storage -- /garage key rename GK1234567890abcdef "new-name"
```

### Delete a Key

```bash
kubectl exec -n garage-storage deployment/garage-s3-storage -- /garage key delete GK1234567890abcdef
```

---

## Permission Management

### Grant Bucket Permissions to Key

**Read-Write Access:**
```bash
kubectl exec -n garage-storage deployment/garage-s3-storage -- /garage bucket allow \
  --read --write \
  my-bucket-name \
  --key GK1234567890abcdef
```

**Read-Only Access:**
```bash
kubectl exec -n garage-storage deployment/garage-s3-storage -- /garage bucket allow \
  --read \
  my-bucket-name \
  --key GK1234567890abcdef
```

**Write-Only Access:**
```bash
kubectl exec -n garage-storage deployment/garage-s3-storage -- /garage bucket allow \
  --write \
  my-bucket-name \
  --key GK1234567890abcdef
```

**Owner Access (Full Control):**
```bash
kubectl exec -n garage-storage deployment/garage-s3-storage -- /garage bucket allow \
  --read --write --owner \
  my-bucket-name \
  --key GK1234567890abcdef
```

### Revoke Bucket Permissions

**Remove all permissions:**
```bash
kubectl exec -n garage-storage deployment/garage-s3-storage -- /garage bucket deny \
  my-bucket-name \
  --key GK1234567890abcdef
```

### View Bucket Permissions

```bash
kubectl exec -n garage-storage deployment/garage-s3-storage -- /garage bucket info my-bucket-name
```

---

## Common Workflows

### Workflow 1: Create User with Full Access to New Bucket

```bash
# Step 1: Create bucket
kubectl exec -n garage-storage deployment/garage-s3-storage -- /garage bucket create production-data

# Step 2: Create API key for user
kubectl exec -n garage-storage deployment/garage-s3-storage -- /garage key new --name "prod-user"
# Output: Key ID: GK1a2b3c4d5e6f7890 | Secret: xyz...

# Step 3: Grant full access to bucket
kubectl exec -n garage-storage deployment/garage-s3-storage -- /garage bucket allow \
  --read --write --owner \
  production-data \
  --key GK1a2b3c4d5e6f7890

# Step 4: Verify permissions
kubectl exec -n garage-storage deployment/garage-s3-storage -- /garage bucket info production-data
```

### Workflow 2: Create Read-Only Backup User

```bash
# Create backup key
kubectl exec -n garage-storage deployment/garage-s3-storage -- /garage key new --name "backup-readonly"
# Output: Key ID: GK9z8y7x6w5v4u3210 | Secret: abc...

# Grant read-only access to all critical buckets
kubectl exec -n garage-storage deployment/garage-s3-storage -- /garage bucket allow \
  --read \
  production-data \
  --key GK9z8y7x6w5v4u3210

kubectl exec -n garage-storage deployment/garage-s3-storage -- /garage bucket allow \
  --read \
  user-uploads \
  --key GK9z8y7x6w5v4u3210
```

### Workflow 3: Create Service Account for Application

```bash
# Create service account key
kubectl exec -n garage-storage deployment/garage-s3-storage -- /garage key new --name "webapp-service"
# Output: Key ID: GKapp123service456 | Secret: svc...

# Grant specific permissions based on app needs
kubectl exec -n garage-storage deployment/garage-s3-storage -- /garage bucket allow \
  --read --write \
  app-assets \
  --key GKapp123service456
```

### Workflow 4: Migrate User to New Key (Key Rotation)

```bash
# Create new key with same permissions
kubectl exec -n garage-storage deployment/garage-s3-storage -- /garage key new --name "user-rotated"
# Output: Key ID: GKnew123rotated456 | Secret: rot...

# Copy permissions from old key (manually grant same permissions)
kubectl exec -n garage-storage deployment/garage-s3-storage -- /garage bucket allow \
  --read --write \
  my-bucket \
  --key GKnew123rotated456

# Test new key with application, then delete old key
kubectl exec -n garage-storage deployment/garage-s3-storage -- /garage key delete GKold789previous012
```

---

## Monitoring & Troubleshooting

### Check Cluster Status

```bash
kubectl exec -n garage-storage deployment/garage-s3-storage -- /garage status
```

### View Node Information

```bash
kubectl exec -n garage-storage deployment/garage-s3-storage -- /garage node list
```

### Check Storage Metrics

```bash
kubectl exec -n garage-storage deployment/garage-s3-storage -- /garage stats
```

### View Pod Logs

```bash
kubectl logs -n garage-storage deployment/garage-s3-storage --tail=100 -f
```

### Check Health Endpoints

```bash
# Get pod IP
POD_IP=$(kubectl get pod -n garage-storage -l app=garage-s3 -o jsonpath='{.items[0].status.podIP}')

# Check health (requires admin token from ConfigMap)
kubectl exec -n garage-storage deployment/garage-s3-storage -- curl -H "Authorization: Bearer YOUR_ADMIN_TOKEN" http://localhost:3903/health
```

### Restart Garage Deployment

```bash
kubectl rollout restart deployment/garage-s3-storage -n garage-storage
```

### Check Resource Usage

```bash
kubectl top pod -n garage-storage
```

### Describe Pod for Detailed Status

```bash
kubectl describe pod -n garage-storage -l app=garage-s3
```

### Access Interactive Shell (Advanced Debugging)

```bash
kubectl exec -it -n garage-storage deployment/garage-s3-storage -- /bin/sh
```

Once inside:
```bash
# Check mounted volumes
df -h

# Verify TOML configuration
cat /etc/garage/garage.toml

# Check data directory
ls -lah /mnt/data

# Check metadata directory
ls -lah /mnt/meta

# Exit shell
exit
```

---

## Performance Testing with kubectl

### Upload Test File

```bash
# Create test file locally (1GB)
dd if=/dev/urandom of=test-1gb.bin bs=1M count=1024

# Use AWS CLI configured with Garage credentials
aws s3 cp test-1gb.bin s3://my-bucket/test-1gb.bin --endpoint-url https://s3.storage-nas.example.com
```

### Download Test File

```bash
aws s3 cp s3://my-bucket/test-1gb.bin ./downloaded-test.bin --endpoint-url https://s3.storage-nas.example.com
```

**Expected Performance (Based on Optimization):**
- Upload/Download: 32 MiB/s (267 Mbit/s) on 1Gbit connection
- Throughput: ~21-27% network utilization

---

## Configuration Reference

### Viewing Current Configuration

```bash
kubectl exec -n garage-storage deployment/garage-s3-storage -- cat /etc/garage/garage.toml
```

### Updating Configuration

1. Edit ConfigMap:
```bash
kubectl edit configmap garage-config -n garage-storage
```

2. Restart deployment to apply changes:
```bash
kubectl rollout restart deployment/garage-s3-storage -n garage-storage
```

---

## Security Best Practices

1. **Never commit Secret Keys to version control**
2. **Rotate API keys regularly** (every 90 days recommended)
3. **Use read-only keys for backup applications**
4. **Grant minimum required permissions** (principle of least privilege)
5. **Monitor access logs** via kubectl logs
6. **Secure admin token** in ConfigMap (consider using Kubernetes Secrets)
7. **Enable HTTPS/TLS** for all ingress endpoints in production

---

## Additional Resources

- Official Garage Documentation: https://garagehq.deuxfleurs.fr/documentation/
- S3 API Compatibility: https://garagehq.deuxfleurs.fr/documentation/reference-manual/s3-compatibility/
- Kubernetes Best Practices: https://kubernetes.io/docs/concepts/configuration/overview/

---

**Need Help?**
- Check pod logs: `kubectl logs -n garage-storage deployment/garage-s3-storage`
- Review events: `kubectl get events -n garage-storage --sort-by='.lastTimestamp'`
- Describe pod: `kubectl describe pod -n garage-storage -l app=garage-s3`
