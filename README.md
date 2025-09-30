# Garage S3 Storage - Kubernetes Deployment

A production-ready deployment of [Garage](https://garagehq.deuxfleurs.fr/) - a lightweight, self-hosted, S3-compatible object storage system optimized for Kubernetes environments.

> **📚 Educational Example Implementation**  
> This repository serves as an example implementation for educational purposes. It demonstrates best practices for deploying S3-compatible object storage on Kubernetes with performance optimizations, security considerations, and operational patterns. While the configurations are production-tested, you should review and adapt them to meet your specific security, compliance, and infrastructure requirements before deploying to production environments.

## 🎯 Features

- ✅ **High Performance:** Optimized configuration achieving 32 MiB/s (267 Mbit/s) throughput on 1Gbit connections over long distances.
- ✅ **S3 Compatible:** Drop-in replacement for AWS S3 with standard S3 API
- ✅ **Single-Node Mode:** Perfect for small to medium deployments without replication overhead
- ✅ **kubectl-Only Management:** No external tools required for administration
- ✅ **Production Tested:** Battle-tested configuration with performance optimizations
- ✅ **LMDB Backend:** Fast, reliable metadata storage for single-node deployments
- ✅ **Resource Optimized:** Tuned resource limits (4Gi memory, 2000m CPU) for optimal performance

## 📋 Table of Contents

- [Prerequisites](#prerequisites)
- [Quick Start](#quick-start)
- [Detailed Installation](#detailed-installation)
- [Configuration](#configuration)
- [Management](#management)
- [Performance Tuning](#performance-tuning)
- [Troubleshooting](#troubleshooting)
- [Architecture](#architecture)

---

## Prerequisites

### Required

- **Kubernetes Cluster:** v1.28+ (tested on RKE2 v1.32.7)
- **kubectl:** Configured with cluster admin access
- **Storage:** At least 100GB available on worker node (adjust based on needs)
- **Network:** 1Gbit+ connection recommended for optimal performance

### Optional

- **Ingress Controller:** nginx-ingress (for external HTTPS access)
- **Cert-Manager:** For automatic SSL/TLS certificate management
- **DNS:** Custom domain for S3 API endpoint

### Cluster Verification

```bash
# Check Kubernetes version
kubectl version --short

# List available worker nodes
kubectl get nodes -o wide

# Verify ingress controller (if using external access)
kubectl get pods -n ingress-nginx
```

---

## Quick Start

### 1. Prepare Worker Node Storage

**SSH to your designated worker node:**

```bash
# Find available nodes
kubectl get nodes -o wide

# SSH to chosen worker node
ssh user@worker-node-01
```

**Run setup script on worker node:**

```bash
# Clone this repository to the worker node
git clone https://github.com/yourusername/garage-k8s-deployment.git
cd garage-k8s-deployment

# Run storage setup script (creates /mnt/storage-data/garage/{data,meta,app})
chmod +x scripts/setup-worker-node-storage.sh
./scripts/setup-worker-node-storage.sh

# Verify directories created
ls -lah /mnt/storage-data/garage/
```

**Expected output:**
```
drwxr-xr-x 5 root root 4096 Jan 1 12:00 .
drwxr-xr-x 3 root root 4096 Jan 1 12:00 ..
drwxr-xr-x 2 root root 4096 Jan 1 12:00 app
drwxr-xr-x 2 root root 4096 Jan 1 12:00 data
drwxr-xr-x 2 root root 4096 Jan 1 12:00 meta
```

### 2. Generate Security Tokens

**On your local machine (with kubectl access):**

```bash
# Generate secure random tokens
chmod +x scripts/generate-secrets.sh
./scripts/generate-secrets.sh
```

**Save the output tokens:**
```
RPC_SECRET=a1b2c3d4e5f6...
ADMIN_TOKEN=xyz123abc456...
METRICS_TOKEN=def789ghi012...
```

### 3. Configure Deployment

**Edit `manifests/01-configmap-garage-toml.yaml`:**

Replace these placeholders with your generated tokens:
```yaml
rpc_secret = "PASTE_YOUR_RPC_SECRET_HERE"
admin_token = "PASTE_YOUR_ADMIN_TOKEN_HERE"
metrics_token = "PASTE_YOUR_METRICS_TOKEN_HERE"
```

**Edit `manifests/02-deployment.yaml`:**

Update the nodeSelector to match your worker node:
```yaml
nodeSelector:
  kubernetes.io/hostname: "worker-node-01"  # Replace with your actual node hostname
```

Update health probe admin tokens (2 locations):
```yaml
httpHeaders:
- name: Authorization
  value: "Bearer PASTE_YOUR_ADMIN_TOKEN_HERE"  # Same token from ConfigMap
```

**Optional - Update hostPath volumes if using custom storage path:**
```yaml
volumes:
- name: garage-data
  hostPath:
    path: /mnt/storage-data/garage/data  # Update if you used different path
```

### 4. Deploy to Kubernetes

```bash
# Apply all manifests in order
kubectl apply -f manifests/

# Verify deployment
kubectl get pods -n garage-storage
kubectl get svc -n garage-storage
kubectl get ingress -n garage-storage
```

**Expected output:**
```
NAME                                READY   STATUS    RESTARTS   AGE
garage-s3-storage-xxxxxxxxxx-xxxxx   1/1     Running   0          1m
```

### 5. Verify Installation

```bash
# Check pod status
kubectl describe pod -n garage-storage -l app=garage-s3

# View logs
kubectl logs -n garage-storage deployment/garage-s3-storage --tail=50

# Check cluster status
kubectl exec -n garage-storage deployment/garage-s3-storage -- /garage status
```

---

## Detailed Installation

### Step-by-Step Configuration Guide

#### 1. Storage Path Customization

If you need to use a different storage path (default is `/mnt/storage-data/garage`):

**On worker node:**
```bash
# Create custom path
sudo mkdir -p /custom/path/garage/{data,meta,app}
sudo chmod -R 755 /custom/path/garage
```

**Update manifests:**
- Edit `manifests/02-deployment.yaml`
- Update all three hostPath volumes:
```yaml
- name: garage-data
  hostPath:
    path: /custom/path/garage/data
- name: garage-meta
  hostPath:
    path: /custom/path/garage/meta
- name: garage-app
  hostPath:
    path: /custom/path/garage/app
```

#### 2. Domain Configuration (Optional)

For external HTTPS access, update ingress files with your domains:

**Edit `manifests/04-ingress-s3-api.yaml`:**
```yaml
spec:
  tls:
  - hosts:
    - s3.yourdomain.com  # Replace with your actual domain
    secretName: garage-s3-api-tls
  rules:
  - host: s3.yourdomain.com  # Replace with your actual domain
```

**Edit `manifests/05-ingress-admin.yaml` and `manifests/06-ingress-rpc.yaml` similarly.**

**Uncomment cert-manager annotation if using automatic SSL:**
```yaml
annotations:
  cert-manager.io/cluster-issuer: "letsencrypt-prod"  # Uncomment this line
```

#### 3. Resource Limits Adjustment

Current configuration uses 4Gi memory and 2000m CPU (tested for high performance).

**To adjust for smaller deployments, edit `manifests/02-deployment.yaml`:**

```yaml
resources:
  requests:
    memory: "1Gi"      # Minimum: 512Mi
    cpu: "500m"        # Minimum: 250m
  limits:
    memory: "2Gi"      # Adjust based on data size
    cpu: "1000m"       # Adjust based on throughput needs
```

**Performance impact:**
- 4Gi/2000m: 32 MiB/s (267 Mbit/s) - **Recommended for production**
- 2Gi/1000m: ~20-25 MiB/s - Moderate performance
- 512Mi/250m: ~10-15 MiB/s - Minimal deployment

---

## Configuration

### Understanding garage.toml

The `manifests/01-configmap-garage-toml.yaml` contains the Garage configuration.

**Key sections:**

```toml
# Storage paths (match deployment volumeMounts)
metadata_dir = "/mnt/meta"
data_dir = "/mnt/data"

# Database engine (LMDB for single-node)
db_engine = "lmdb"

# Replication mode (none for single-node)
replication_mode = "none"

# Security tokens (CHANGE THESE!)
rpc_secret = "YOUR_64_CHAR_HEX_STRING"

# S3 API configuration
[s3_api]
s3_region = "us-east-1"
api_bind_addr = "[::]:3900"
root_domain = ".s3.storage-nas.example.com"  # For virtual-hosted-style requests

# Admin API configuration
[admin]
api_bind_addr = "[::]:3903"
admin_token = "YOUR_ADMIN_TOKEN"
```

### Customization Options

| Parameter | Default | Description | When to Change |
|-----------|---------|-------------|----------------|
| `db_engine` | `lmdb` | Metadata storage | Use `sqlite` for multi-node clusters |
| `replication_mode` | `none` | Data replication | Use `2` or `3` for multi-node HA |
| `compression_level` | `1` | Zstd compression | Increase for bandwidth-limited networks |
| `s3_region` | `us-east-1` | S3 region name | Match your application expectations |
| `root_domain` | `.s3.storage-nas.example.com` | Virtual-hosted URLs | Set to your actual domain |

---

## Management

All management is done via kubectl. See [CLI-MANAGEMENT.md](CLI-MANAGEMENT.md) for comprehensive guide.

### Common Tasks

**Create a bucket:**
```bash
kubectl exec -n garage-storage deployment/garage-s3-storage -- /garage bucket create my-bucket
```

**Create API key:**
```bash
kubectl exec -n garage-storage deployment/garage-s3-storage -- /garage key new --name "my-user"
# Output: Key ID: GK... | Secret: ...
```

**Grant permissions:**
```bash
kubectl exec -n garage-storage deployment/garage-s3-storage -- /garage bucket allow \
  --read --write \
  my-bucket \
  --key GK1234567890abcdef
```

**List buckets:**
```bash
kubectl exec -n garage-storage deployment/garage-s3-storage -- /garage bucket list
```

**Check status:**
```bash
kubectl exec -n garage-storage deployment/garage-s3-storage -- /garage status
```

---

## Performance Tuning

This deployment includes battle-tested performance optimizations.

### Current Performance Benchmarks

**Hardware:**
- Network: 1Gbit up/down
- Storage: Local SSD on worker node
- CPU: 2000m allocated (2 cores)
- Memory: 4Gi allocated

**Results:**
- Upload Speed: 32 MiB/s (267 Mbit/s)
- Download Speed: 32 MiB/s (267 Mbit/s)
- Network Utilization: 21-27%
- Latency: <50ms (local network)

### Applied Optimizations

#### 1. Resource Limits
Increased from default 512Mi/250m to 4Gi/2000m:
- **Impact:** +14% throughput improvement
- **Location:** `manifests/02-deployment.yaml`

#### 2. Ingress Performance
```yaml
nginx.ingress.kubernetes.io/proxy-buffering: "off"
nginx.ingress.kubernetes.io/proxy-request-buffering: "off"
nginx.ingress.kubernetes.io/client-max-body-size: "5g"
nginx.ingress.kubernetes.io/proxy-connect-timeout: "300"
nginx.ingress.kubernetes.io/proxy-send-timeout: "300"
nginx.ingress.kubernetes.io/proxy-read-timeout: "300"
```
- **Impact:** +14% throughput improvement
- **Location:** All ingress files (`manifests/04-*.yaml`, `05-*.yaml`, `06-*.yaml`)

#### 3. CORS Configuration
Enables S3 API compatibility for web applications:
- **Location:** `manifests/04-ingress-s3-api.yaml`
- **Headers:** Exposes ETag, x-amz-request-id for proper S3 behavior

### Additional Tuning (Advanced)

**For higher throughput:**
1. Increase resource limits to 8Gi/4000m
2. Use dedicated storage nodes with NVMe SSDs
3. Enable 10Gbit networking on worker nodes
4. Disable TLS termination (use direct HTTP) for internal-only access

**For lower resource usage:**
1. Reduce limits to 2Gi/1000m (expect ~20 MiB/s)
2. Enable compression_level=3 in garage.toml
3. Use HDD storage for cold data (expect ~80-100 MiB/s)

---

## Troubleshooting

### Pod Not Starting

**Symptom:** Pod stuck in `Pending` or `CrashLoopBackOff`

**Check node selector:**
```bash
kubectl describe pod -n garage-storage -l app=garage-s3
```

Look for: `Node-Selectors: kubernetes.io/hostname=worker-node-01`

**Verify storage directories exist on worker node:**
```bash
ssh user@worker-node-01 "ls -lah /mnt/storage-data/garage"
```

**Expected output:** Three directories (data, meta, app)

### Health Probe Failures

**Symptom:** Pod shows `0/1` ready, logs show `Liveness probe failed: HTTP probe failed`

**Cause:** Admin token mismatch between ConfigMap and Deployment health probes

**Fix:**
1. Check ConfigMap admin token:
```bash
kubectl get configmap garage-config -n garage-storage -o yaml | grep admin_token
```

2. Check Deployment health probe token:
```bash
kubectl get deployment garage-s3-storage -n garage-storage -o yaml | grep Authorization
```

3. Ensure both match exactly (including "Bearer " prefix in deployment)

### Permission Denied Errors

**Symptom:** Pod crashes with "Permission denied" in logs

**Check directory permissions on worker node:**
```bash
ssh user@worker-node-01 "sudo ls -lah /mnt/storage-data/garage"
```

**Fix permissions:**
```bash
ssh user@worker-node-01 "sudo chmod -R 755 /mnt/storage-data/garage"
```

### Ingress Not Working

**Symptom:** External access returns 502/503/404 errors

**Verify service endpoints:**
```bash
kubectl get endpoints -n garage-storage
```

Expected: Should show pod IP with ports 3900, 3901, 3903

**Check ingress controller:**
```bash
kubectl get pods -n ingress-nginx
kubectl logs -n ingress-nginx deployment/nginx-ingress-controller | grep garage
```

**Verify DNS resolution:**
```bash
nslookup s3.yourdomain.com
```

### Low Performance

**Symptom:** Upload/download speeds below 20 MiB/s

**Check resource usage:**
```bash
kubectl top pod -n garage-storage
```

**If CPU/Memory maxed out:**
1. Increase resource limits in `manifests/02-deployment.yaml`
2. Restart deployment: `kubectl rollout restart deployment/garage-s3-storage -n garage-storage`

**Check network bottlenecks:**
```bash
# Test network speed to worker node
iperf3 -c worker-node-01
```

**Verify ingress annotations applied:**
```bash
kubectl get ingress garage-s3-api -n garage-storage -o yaml | grep proxy-buffering
```

Should show: `nginx.ingress.kubernetes.io/proxy-buffering: "off"`

---

## Architecture

### Component Overview

```
┌─────────────────────────────────────────────────────────────┐
│                        Kubernetes Cluster                    │
├─────────────────────────────────────────────────────────────┤
│                                                               │
│  ┌───────────────────────────────────────────────────────┐  │
│  │             Namespace: garage-storage                  │  │
│  │                                                         │  │
│  │  ┌─────────────────────────────────────────────────┐  │  │
│  │  │  ConfigMap: garage-config                        │  │  │
│  │  │  - garage.toml configuration                     │  │  │
│  │  │  - RPC secret, admin token, metrics token        │  │  │
│  │  └─────────────────────────────────────────────────┘  │  │
│  │                                                         │  │
│  │  ┌─────────────────────────────────────────────────┐  │  │
│  │  │  Deployment: garage-s3-storage                   │  │  │
│  │  │  - Image: dxflrs/garage:v1.0.0                   │  │  │
│  │  │  - Resources: 4Gi memory, 2000m CPU              │  │  │
│  │  │  - Volumes: data, meta, app (hostPath)           │  │  │
│  │  │  - Ports: 3900 (S3), 3901 (RPC), 3903 (Admin)    │  │  │
│  │  └─────────────────────────────────────────────────┘  │  │
│  │                            │                            │  │
│  │  ┌─────────────────────────────────────────────────┐  │  │
│  │  │  Service: garage-s3-service (ClusterIP)          │  │  │
│  │  │  - S3 API: 3900                                  │  │  │
│  │  │  - RPC: 3901                                     │  │  │
│  │  │  - Admin: 3903                                   │  │  │
│  │  └─────────────────────────────────────────────────┘  │  │
│  │                            │                            │  │
│  │  ┌─────────────────────────────────────────────────┐  │  │
│  │  │  Ingress: garage-s3-api                          │  │  │
│  │  │  - Host: s3.storage-nas.example.com              │  │  │
│  │  │  - TLS: cert-manager (optional)                  │  │  │
│  │  │  - Performance optimizations enabled             │  │  │
│  │  └─────────────────────────────────────────────────┘  │  │
│  │                                                         │  │
│  │  ┌─────────────────────────────────────────────────┐  │  │
│  │  │  Ingress: garage-admin-api                       │  │  │
│  │  │  - Host: admin.storage-nas.example.com           │  │  │
│  │  └─────────────────────────────────────────────────┘  │  │
│  │                                                         │  │
│  │  ┌─────────────────────────────────────────────────┐  │  │
│  │  │  Ingress: garage-rpc-api                         │  │  │
│  │  │  - Host: rpc.storage-nas.example.com             │  │  │
│  │  └─────────────────────────────────────────────────┘  │  │
│  └───────────────────────────────────────────────────────┘  │
│                                                               │
│  ┌───────────────────────────────────────────────────────┐  │
│  │  Worker Node: worker-node-01                          │  │
│  │  ┌─────────────────────────────────────────────────┐  │  │
│  │  │  /mnt/storage-data/garage/                       │  │  │
│  │  │  ├── data/   (Object storage)                    │  │  │
│  │  │  ├── meta/   (LMDB database)                     │  │  │
│  │  │  └── app/    (Application files)                 │  │  │
│  │  └─────────────────────────────────────────────────┘  │  │
│  └───────────────────────────────────────────────────────┘  │
└─────────────────────────────────────────────────────────────┘
```

### Data Flow

1. **External S3 Client** → DNS (s3.yourdomain.com) → **Ingress Controller**
2. **Ingress Controller** → **Service (ClusterIP)** → **Pod (Garage)**
3. **Garage Pod** → **hostPath Volumes** → **Worker Node Storage**

### Port Mapping

| Port | Protocol | Purpose | Exposed Via |
|------|----------|---------|-------------|
| 3900 | HTTP | S3 API | Ingress (s3.yourdomain.com) |
| 3901 | HTTP | RPC (inter-node communication) | Ingress (rpc.yourdomain.com) |
| 3902 | HTTP | Web interface (static sites) | Not exposed by default |
| 3903 | HTTP | Admin API | Ingress (admin.yourdomain.com) |

---

## Security Considerations

### Production Checklist

- [ ] Generate unique RPC secret, admin token, metrics token (never use defaults!)
- [ ] Store tokens in Kubernetes Secrets instead of ConfigMap (recommended)
- [ ] Enable TLS/HTTPS for all ingress endpoints via cert-manager
- [ ] Restrict ingress access with IP allowlists (nginx.ingress.kubernetes.io/whitelist-source-range)
- [ ] Use NetworkPolicies to limit pod-to-pod communication
- [ ] Enable audit logging on Kubernetes API server
- [ ] Regularly rotate API keys (every 90 days)
- [ ] Monitor access logs: `kubectl logs -n garage-storage deployment/garage-s3-storage`
- [ ] Backup metadata database regularly (LMDB file in /mnt/storage-data/garage/meta)

### Secrets Management (Advanced)

Convert ConfigMap to Secret:

```bash
# Create secret from file
kubectl create secret generic garage-secrets \
  --from-file=garage.toml=manifests/01-configmap-garage-toml.yaml \
  -n garage-storage

# Update deployment to use secret instead of configmap
kubectl edit deployment garage-s3-storage -n garage-storage
```

Change:
```yaml
- name: garage-config
  configMap:
    name: garage-config
```

To:
```yaml
- name: garage-config
  secret:
    secretName: garage-secrets
```

---

## Additional Resources

- **Official Documentation:** https://garagehq.deuxfleurs.fr/documentation/
- **S3 API Compatibility:** https://garagehq.deuxfleurs.fr/documentation/reference-manual/s3-compatibility/
- **CLI Management Guide:** [CLI-MANAGEMENT.md](CLI-MANAGEMENT.md)
- **GitHub Repository:** https://git.deuxfleurs.fr/Deuxfleurs/garage

---

## License

This deployment configuration is provided as-is under MIT License.

Garage itself is licensed under AGPL-3.0. See https://git.deuxfleurs.fr/Deuxfleurs/garage for details.

---

## Contributing

Issues and pull requests welcome! Please ensure:
1. All placeholders remain synthetic (no real credentials/domains)
2. kubectl-only patterns maintained (no external tool dependencies)
3. Documentation updated for any configuration changes

---

**Questions or Issues?**

Open an issue on GitHub or check the [Troubleshooting](#troubleshooting) section above.
