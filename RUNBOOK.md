# 📖 Mule Trading App - Run Book

## 🏗️ Prerequisites & Versions

### Required Software
```bash
# Check versions
java -version          # OpenJDK 17.0.2+8
mvn --version         # Apache Maven 3.9.9
docker --version      # Docker version 28.3.3
kubectl version       # Client v1.33.4
psql --version        # PostgreSQL 15.x
```

### Environment Variables
```bash
export JAVA_HOME=/usr/lib/jvm/java-17-openjdk-amd64
export M2_HOME=/opt/maven
export PATH=$PATH:$M2_HOME/bin
```

---

## 🚀 One-Time Setup

### 1. Clone Repository
```bash
git clone https://github.com/wedhazo/demo.git
cd demo
```

### 2. Database Setup
```bash
# Start PostgreSQL
sudo systemctl start postgresql

# Create database and user
sudo -u postgres psql << EOF
CREATE DATABASE tft_trading;
CREATE USER postgres WITH PASSWORD 'postgres123';
GRANT ALL PRIVILEGES ON DATABASE tft_trading TO postgres;
\q
EOF

# Load sample data (if available)
psql -h localhost -U postgres -d tft_trading -f data/sample_market_data.sql
```

### 3. Kubernetes Cluster Setup
```bash
# Create Kind cluster
kind create cluster --name mulesoft-cluster

# Create namespaces
kubectl create namespace mule-dev
kubectl create namespace mule-test
kubectl create namespace mule-prod
kubectl create namespace monitoring
kubectl create namespace jenkins
kubectl create namespace artifactory

# Apply all K8s manifests
kubectl apply -f k8s/
```

### 4. Docker Registry Login
```bash
# Login to GitHub Container Registry
echo $GITHUB_TOKEN | docker login ghcr.io -u wedhazo --password-stdin
```

---

## 📅 Daily Use

### Quick Status Check
```bash
echo "=== STATUS CHECK ===" && \
echo "Maven JAR:" && ls -la target/*.jar 2>/dev/null || echo "No JAR found" && \
echo "Docker images:" && docker images | grep mule-trading-app && \
echo "K8s pods:" && kubectl get pods -n mule-dev
```

### Development Workflow
```bash
# 1. Pull latest changes
git pull origin main

# 2. Make changes to src/main/mule/*.xml or properties

# 3. Test locally (see Local Run section)

# 4. Commit and push
git add .
git commit -m "feat: your changes"
git push origin main
```

---

## 🔐 Secrets Management

### Local Development
```bash
# Set environment variables
export DB_PASSWORD="postgres123"
export MULE_ENV="dev"

# Verify secrets are loaded
echo "DB_PASSWORD is set: ${DB_PASSWORD:+YES}"
echo "MULE_ENV is set: ${MULE_ENV}"
```

### Production Secrets
```bash
# Jenkins Credentials (configured in Jenkins UI)
ID: db-password        → Secret: postgres123
ID: github-token       → Secret: ghp_xxxxxxxxxxxx
ID: kubeconfig         → File: ~/.kube/config

# Kubernetes Secrets
kubectl create secret generic db-credentials \
  --from-literal=DB_PASSWORD=postgres123 \
  -n mule-dev
```

### Secret Rotation
```bash
# Update password in all environments
NEW_PASSWORD="newSecurePassword123"

# 1. Update Jenkins credential
# 2. Update Kubernetes secret
kubectl patch secret db-credentials -n mule-dev \
  -p '{"data":{"DB_PASSWORD":"'$(echo -n $NEW_PASSWORD | base64)'"}}'

# 3. Restart pods to pick up new secret
kubectl rollout restart deployment/mule-app -n mule-dev
```

---

## 🏃‍♂️ Local Run

### Method 1: Maven Run
```bash
# Set environment
export DB_PASSWORD="postgres123"
export MULE_ENV="dev"

# Clean and compile
mvn clean compile -Dmule.env=dev

# Run application
mvn mule:run -Dmule.env=dev
```

### Method 2: JAR Run
```bash
# Build JAR
mvn clean package -Dmule.env=dev

# Run JAR (if supported)
java -jar target/demo-1.0.0-SNAPSHOT-mule-application.jar
```

### Verify Local Run
```bash
# Test endpoint
curl -s http://localhost:8081/kb | jq .

# Expected response: JSON array with NVDA stock data
# [{"symbol":"NVDA","timestamp":"2024-01-15T09:30:00Z",...}]
```

---

## 🧪 Test

### Unit Tests
```bash
# Run all tests
mvn test

# Run specific test
mvn test -Dtest=DemoFlowTest

# Skip tests during build
mvn clean package -DskipTests
```

### Integration Tests
```bash
# Start database first
docker run -d --name postgres-test \
  -e POSTGRES_DB=tft_trading \
  -e POSTGRES_USER=postgres \
  -e POSTGRES_PASSWORD=postgres123 \
  -p 5433:5432 postgres:15

# Run integration tests
export DB_PASSWORD="postgres123"
mvn verify -Dmule.env=test
```

### API Testing
```bash
# Health check
curl -f http://localhost:8081/kb

# Performance test
for i in {1..10}; do
  curl -s -w "%{time_total}\n" -o /dev/null http://localhost:8081/kb
done
```

---

## 🏗️ Build

### Local Build
```bash
# Clean build
mvn clean package -Dmule.env=dev

# Build with tests
mvn clean verify -Dmule.env=dev

# Build for specific environment
mvn clean package -Dmule.env=prod -DskipTests
```

### CI/CD Build (Jenkins)
```bash
# Trigger build manually
curl -X POST http://localhost:8080/job/mule-trading-app-pipeline/build \
  --user admin:$JENKINS_API_TOKEN

# Check build status
curl -s http://localhost:8080/job/mule-trading-app-pipeline/lastBuild/api/json | jq .result
```

---

## 🐳 Dockerize

### Build Docker Image
```bash
# Build with current timestamp tag
TIMESTAMP=$(date +%Y%m%d-%H%M%S)
docker build -f Dockerfile.simulator -t mule-trading-app:$TIMESTAMP .

# Build with latest tag
docker build -f Dockerfile.simulator -t mule-trading-app:latest .

# Build with secrets
docker build \
  --build-arg DB_PASSWORD="postgres123" \
  --build-arg MULE_ENV="dev" \
  -f Dockerfile.simulator \
  -t mule-trading-app:latest .
```

### Test Docker Image
```bash
# Run container
docker run -d --name mule-app-test \
  -e DB_PASSWORD="postgres123" \
  -e MULE_ENV="dev" \
  -p 8082:8081 \
  mule-trading-app:latest

# Test endpoint
curl -s http://localhost:8082/kb | jq .

# Check logs
docker logs mule-app-test

# Cleanup
docker stop mule-app-test && docker rm mule-app-test
```

### Push to Registry
```bash
# Tag for registry
docker tag mule-trading-app:latest ghcr.io/wedhazo/demo:latest

# Push to GitHub Container Registry
docker push ghcr.io/wedhazo/demo:latest

# Push with version tag
GIT_COMMIT=$(git rev-parse --short HEAD)
docker tag mule-trading-app:latest ghcr.io/wedhazo/demo:$GIT_COMMIT
docker push ghcr.io/wedhazo/demo:$GIT_COMMIT
```

---

## ☸️ Deploy to Kubernetes

### Deploy to Development
```bash
# Apply all manifests
kubectl apply -f k8s/

# Check deployment status
kubectl get deployments -n mule-dev
kubectl get pods -n mule-dev
kubectl get services -n mule-dev
```

### Deploy Specific Version
```bash
# Update image to specific version
kubectl set image deployment/mule-app \
  mule-app=ghcr.io/wedhazo/demo:abc1234 \
  -n mule-dev

# Wait for rollout
kubectl rollout status deployment/mule-app -n mule-dev --timeout=300s
```

### Scale Deployment
```bash
# Scale up
kubectl scale deployment mule-app --replicas=3 -n mule-dev

# Scale down
kubectl scale deployment mule-app --replicas=1 -n mule-dev

# Auto-scale (HPA should be configured)
kubectl autoscale deployment mule-app --cpu-percent=70 --min=1 --max=5 -n mule-dev
```

### Environment Promotion
```bash
# Deploy to test environment
kubectl apply -f k8s/ -n mule-test

# Deploy to production
kubectl apply -f k8s/ -n mule-prod
```

---

## 🔄 Rollback

### Kubernetes Rollback
```bash
# Check rollout history
kubectl rollout history deployment/mule-app -n mule-dev

# Rollback to previous version
kubectl rollout undo deployment/mule-app -n mule-dev

# Rollback to specific revision
kubectl rollout undo deployment/mule-app --to-revision=2 -n mule-dev

# Verify rollback
kubectl rollout status deployment/mule-app -n mule-dev
```

### Docker Rollback
```bash
# List available images
docker images ghcr.io/wedhazo/demo

# Deploy previous version
PREVIOUS_TAG="abc1234"
kubectl set image deployment/mule-app \
  mule-app=ghcr.io/wedhazo/demo:$PREVIOUS_TAG \
  -n mule-dev
```

### Git Rollback
```bash
# Revert last commit
git revert HEAD

# Reset to specific commit
git reset --hard abc1234

# Create hotfix branch
git checkout -b hotfix/rollback-issue
```

---

## 📊 Logs

### Application Logs
```bash
# Kubernetes pod logs
kubectl logs -n mule-dev -l app=mule-app --tail=50

# Follow logs in real-time
kubectl logs -n mule-dev -l app=mule-app -f

# Logs from specific pod
kubectl logs -n mule-dev mule-app-7d8b9c5f6d-x1y2z

# Previous container logs (if pod restarted)
kubectl logs -n mule-dev mule-app-7d8b9c5f6d-x1y2z --previous
```

### Docker Logs
```bash
# Container logs
docker logs mule-app-container

# Follow logs
docker logs -f mule-app-container

# Last 100 lines
docker logs --tail 100 mule-app-container
```

### Local Logs
```bash
# Maven build logs
mvn clean package > build.log 2>&1

# Mule runtime logs
tail -f logs/mule_ee.log

# Application-specific logs
tail -f logs/demo.log
```

### Centralized Logging
```bash
# Prometheus logs
kubectl logs -n monitoring -l app=prometheus

# Grafana logs
kubectl logs -n monitoring -l app=grafana

# Export logs to file
kubectl logs -n mule-dev -l app=mule-app --since=1h > app-logs-$(date +%Y%m%d-%H%M).log
```

---

## 🔧 Troubleshooting

### Top 10 Common Issues & Fixes

#### 1. **Database Connection Failed**
```bash
# Symptoms: "Cannot connect to database" in logs
# Check database status
kubectl get pods -n mule-dev -l app=postgres

# Fix: Restart database pod
kubectl delete pod -n mule-dev -l app=postgres

# Verify connection
kubectl exec -it deployment/postgres -n mule-dev -- psql -U postgres -d tft_trading -c "SELECT 1;"
```

#### 2. **Maven Build Failed**
```bash
# Symptoms: "BUILD FAILURE" with dependency errors
# Clear Maven cache
rm -rf ~/.m2/repository

# Rebuild with clean cache
mvn clean compile -U
```

#### 3. **Docker Build Failed**
```bash
# Symptoms: "No space left on device"
# Clean Docker system
docker system prune -f
docker image prune -a -f

# Check disk space
df -h
```

#### 4. **Kubernetes Pod CrashLoopBackOff**
```bash
# Check pod status
kubectl describe pod -n mule-dev -l app=mule-app

# Check logs for errors
kubectl logs -n mule-dev -l app=mule-app --previous

# Fix: Update resource limits or fix configuration
kubectl edit deployment mule-app -n mule-dev
```

#### 5. **Port Already in Use**
```bash
# Symptoms: "Port 8081 already in use"
# Find process using port
lsof -i :8081

# Kill process
kill -9 <PID>

# Or use different port
export HTTP_PORT=8082
```

#### 6. **Environment Variable Not Set**
```bash
# Symptoms: "Property ${env:DB_PASSWORD} not found"
# Check environment variables
env | grep DB_PASSWORD

# Set missing variable
export DB_PASSWORD="postgres123"

# Verify in Kubernetes
kubectl exec -it deployment/mule-app -n mule-dev -- printenv | grep DB_PASSWORD
```

#### 7. **Git Merge Conflicts**
```bash
# Check conflict status
git status

# See conflicted files
git diff --name-only --diff-filter=U

# For each conflicted file:
# 1. Edit file and resolve conflicts (remove <<<< ==== >>>> markers)
# 2. Add resolved file
git add <resolved-file>

# Continue merge/rebase
git rebase --continue
# OR
git commit
```

#### 8. **Jenkins Build Failed**
```bash
# Check Jenkins logs
kubectl logs -n jenkins -l app=jenkins

# Check build console output in Jenkins UI
# Common fixes:
# - Update Jenkins credentials
# - Clear workspace: rm -rf workspace/*
# - Restart Jenkins pod
kubectl delete pod -n jenkins -l app=jenkins
```

#### 9. **Docker Registry Push Failed**
```bash
# Symptoms: "Authentication required" or "Access denied"
# Re-login to registry
echo $GITHUB_TOKEN | docker login ghcr.io -u wedhazo --password-stdin

# Check token permissions (needs packages:write)
curl -H "Authorization: token $GITHUB_TOKEN" https://api.github.com/user

# Verify image exists locally
docker images | grep mule-trading-app
```

#### 10. **Application Not Responding**
```bash
# Check if application is running
curl -I http://localhost:8081/kb

# Port forward to access K8s service
kubectl port-forward -n mule-dev svc/mule-app-service 8083:8081 &

# Test forwarded port
curl -s http://localhost:8083/kb

# Check application health
kubectl exec -it deployment/mule-app -n mule-dev -- ps aux | grep mule
```

### Emergency Procedures

#### Complete Application Reset
```bash
# 1. Stop all services
kubectl delete deployment mule-app -n mule-dev
docker stop $(docker ps -q --filter ancestor=mule-trading-app)

# 2. Clean build artifacts
mvn clean
rm -rf target/

# 3. Rebuild and redeploy
mvn clean package -Dmule.env=dev
docker build -f Dockerfile.simulator -t mule-trading-app:latest .
kubectl apply -f k8s/
```

#### Disaster Recovery
```bash
# 1. Backup current state
kubectl get all -n mule-dev -o yaml > backup-$(date +%Y%m%d).yaml

# 2. Restore from backup
kubectl apply -f backup-YYYYMMDD.yaml

# 3. Database recovery
pg_dump -h localhost -U postgres tft_trading > db_backup.sql
# Restore: psql -h localhost -U postgres -d tft_trading < db_backup.sql
```

---

## 📞 Support Contacts

- **DevOps Team**: devops-team@company.com
- **Database Admin**: dba-team@company.com
- **Monitoring**: monitoring@company.com
- **Emergency**: +1-555-DEVOPS (24/7)

---

## 🔗 Quick Links

- **GitHub Repository**: https://github.com/wedhazo/demo
- **Jenkins Dashboard**: http://localhost:8080/
- **Grafana Monitoring**: http://localhost:3000/
- **Prometheus Metrics**: http://localhost:9090/
- **Application Health**: http://localhost:8081/kb
