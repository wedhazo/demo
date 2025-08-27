# Jenkins Configuration Guide for Mule Trading App

## 🚀 Complete Setup Checklist

### 1. Jenkins Global Tool Configuration

Navigate to **Manage Jenkins** → **Global Tool Configuration**

#### Java (JDK) Configuration
```
Name: JDK-17
Install automatically: ✅
Version: OpenJDK 17.0.2+8
Or
Install from java.sun.com: OpenJDK 17
```

#### Maven Configuration
```
Name: Maven-3.9
Install automatically: ✅
Version: 3.9.9
```

#### Docker Configuration
```
Name: Docker
Install automatically: ✅
Download from docker.com
```

#### Kubernetes CLI (kubectl)
```
Name: kubectl
Install automatically: ✅
Version: Latest stable
```

### 2. Jenkins Credentials Setup

Navigate to **Manage Jenkins** → **Manage Credentials** → **System** → **Global credentials**

#### Required Credentials:

1. **GitHub Token** (Secret text)
   ```
   ID: github-token
   Description: GitHub Personal Access Token
   Secret: [Your GitHub PAT with repo, packages:write permissions]
   ```

2. **Database Password** (Secret text)
   ```
   ID: db-password
   Description: PostgreSQL Database Password
   Secret: postgres123
   ```

3. **Kubeconfig File** (Secret file)
   ```
   ID: kubeconfig
   Description: Kubernetes cluster configuration
   File: ~/.kube/config (from your Kind cluster)
   ```

4. **Docker Registry Credentials** (Username with password)
   ```
   ID: docker-registry
   Username: wedhazo
   Password: [Your GitHub PAT]
   Description: GitHub Container Registry access
   ```

### 3. Jenkins Plugin Requirements

Ensure these plugins are installed via **Manage Jenkins** → **Manage Plugins**:

#### Essential Plugins:
- **Pipeline** (for declarative pipelines)
- **Git** (for repository integration)
- **GitHub** (for webhook triggers)
- **Docker Pipeline** (for Docker operations)
- **Kubernetes** (for K8s deployments)
- **Credentials Binding** (for secure variable injection)
- **Timestamper** (for build timestamps)
- **Build Timeout** (for pipeline timeouts)
- **Slack Notification** (optional - for notifications)
- **Email Extension** (optional - for email alerts)

#### Installation Commands:
```bash
# Install via Jenkins CLI (if available)
java -jar jenkins-cli.jar -s http://localhost:8080/ install-plugin \
  pipeline-stage-view \
  git \
  github \
  docker-workflow \
  kubernetes \
  credentials-binding \
  timestamper \
  build-timeout \
  slack \
  email-ext
```

### 4. Pipeline Job Creation

1. **Create New Job**
   - Click **New Item**
   - Enter name: `mule-trading-app-pipeline`
   - Select **Pipeline**
   - Click **OK**

2. **Configure Pipeline**
   
   **General Tab:**
   ```
   ✅ GitHub project: https://github.com/wedhazo/demo
   ✅ This project is parameterized (optional)
   ```
   
   **Build Triggers:**
   ```
   ✅ GitHub hook trigger for GITScm polling
   ✅ Poll SCM: H/5 * * * * (every 5 minutes)
   ```
   
   **Pipeline Section:**
   ```
   Definition: Pipeline script from SCM
   SCM: Git
   Repository URL: https://github.com/wedhazo/demo.git
   Credentials: [Select your GitHub credentials]
   Branch: */main
   Script Path: Jenkinsfile.optimized
   ```

### 5. GitHub Webhook Configuration

#### In GitHub Repository Settings:

1. Go to **Settings** → **Webhooks**
2. Click **Add webhook**
3. Configure:
   ```
   Payload URL: http://your-jenkins-url:8080/github-webhook/
   Content type: application/json
   Which events: Just the push event
   Active: ✅
   ```

#### Test Webhook:
```bash
curl -X POST http://localhost:8080/github-webhook/ \
  -H "Content-Type: application/json" \
  -d '{"ref":"refs/heads/main","repository":{"full_name":"wedhazo/demo"}}'
```

### 6. Environment Variables Setup

#### Global Environment Variables (Optional)
Navigate to **Manage Jenkins** → **Configure System** → **Global Properties**

```
Name: DOCKER_REGISTRY
Value: ghcr.io

Name: K8S_NAMESPACE
Value: mule-dev

Name: MULE_DEFAULT_ENV
Value: dev
```

### 7. Security Configuration

#### GitHub Container Registry Access
```bash
# Test Docker login locally first:
echo $GITHUB_TOKEN | docker login ghcr.io -u wedhazo --password-stdin

# Verify push access:
docker tag test-image ghcr.io/wedhazo/test:latest
docker push ghcr.io/wedhazo/test:latest
```

#### Kubernetes Access Verification
```bash
# Test kubectl access:
kubectl get nodes
kubectl get namespaces
kubectl get pods -n mule-dev
```

### 8. Pipeline Execution Flow

#### Build Stages Overview:
1. **Checkout** - Clone repository and set build variables
2. **Cache Setup** - Configure Maven local repository
3. **Build & Test** - Compile Mule app with secure DB_PASSWORD
4. **Docker Build** - Create container image with environment injection
5. **Docker Push** - Push to ghcr.io with git commit tag
6. **Deploy to Kubernetes** - Update deployment and verify rollout
7. **Health Check** - Verify application endpoint responds

#### Expected Build Time: 3-5 minutes

### 9. Monitoring & Troubleshooting

#### Build Logs Location:
```
Jenkins Dashboard → mule-trading-app-pipeline → Build History → #[BUILD_NUMBER] → Console Output
```

#### Common Issues & Solutions:

1. **Maven Build Fails**
   ```bash
   # Check Java version in build logs
   mvn --version
   
   # Verify Maven cache
   ls -la .m2/repository/
   ```

2. **Docker Push Fails**
   ```bash
   # Verify GitHub token permissions
   curl -H "Authorization: token $GITHUB_TOKEN" https://api.github.com/user
   
   # Check registry access
   docker pull ghcr.io/wedhazo/demo:latest
   ```

3. **Kubernetes Deployment Fails**
   ```bash
   # Check cluster access
   kubectl cluster-info
   
   # Verify namespace exists
   kubectl get namespace mule-dev
   
   # Check deployment status
   kubectl describe deployment mule-app -n mule-dev
   ```

### 10. Production Readiness Checklist

#### Before Going Live:
- [ ] All credentials configured securely
- [ ] GitHub webhooks tested and working
- [ ] Docker images pushing successfully to registry
- [ ] Kubernetes deployments completing without errors
- [ ] Health checks passing consistently
- [ ] Notification channels configured (Slack/Email)
- [ ] Backup and rollback procedures documented
- [ ] Resource limits configured in Kubernetes manifests
- [ ] Monitoring and alerting configured (Prometheus/Grafana)

#### Security Verification:
- [ ] No hardcoded secrets in code
- [ ] Database password injected via Jenkins credentials
- [ ] GitHub token has minimal required permissions
- [ ] Kubernetes RBAC properly configured
- [ ] Network policies applied if required

### 11. Maintenance Commands

#### Clean Jenkins Workspace:
```bash
# Via Jenkins CLI
java -jar jenkins-cli.jar -s http://localhost:8080/ clear-cache

# Or via Build → Execute shell
rm -rf .m2/repository/*
docker system prune -f
```

#### Update Pipeline:
```bash
# Pull latest changes
git pull origin main

# Update Jenkinsfile and commit
git add Jenkinsfile.optimized
git commit -m "Update CI/CD pipeline"
git push origin main
```

#### Rollback Deployment:
```bash
# Via kubectl
kubectl rollout undo deployment/mule-app -n mule-dev

# Or via Jenkins parameter
BUILD_NUMBER=42 # Previous successful build
kubectl set image deployment/mule-app mule-app=ghcr.io/wedhazo/demo:build-$BUILD_NUMBER -n mule-dev
```

---

## 🎯 Quick Start Commands

```bash
# 1. Verify Jenkins is running
curl -I http://localhost:8080/

# 2. Test GitHub connectivity
git clone https://github.com/wedhazo/demo.git
cd demo

# 3. Test Docker access
docker login ghcr.io -u wedhazo

# 4. Test Kubernetes access
kubectl get pods -n mule-dev

# 5. Trigger pipeline manually
curl -X POST http://localhost:8080/job/mule-trading-app-pipeline/build \
  --user admin:$JENKINS_API_TOKEN
```

**Your pipeline is now ready for production! 🚀**
