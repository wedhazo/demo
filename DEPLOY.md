# 🚀 Deployment Guide

## Overview

This guide covers deploying the Mule Trading application using Jenkins CI/CD pipeline, including Kubernetes deployment and CloudHub alternatives.

## 🔧 Required Jenkins Credentials

### Configure these credentials in Jenkins before running the pipeline:

#### 1. Database Password
```
Credential Type: Secret text
ID: db-password
Description: PostgreSQL Database Password
Secret: postgres123
Usage: Injected as DB_PASSWORD environment variable
```

#### 2. GitHub Token
```
Credential Type: Secret text
ID: github-token
Description: GitHub Personal Access Token
Secret: ghp_xxxxxxxxxxxxxxxxxxxx
Scopes Required: repo, packages:write, packages:read
Usage: Docker registry authentication (ghcr.io)
```

#### 3. Kubeconfig File
```
Credential Type: Secret file
ID: kubeconfig
Description: Kubernetes cluster configuration
File: Upload your ~/.kube/config file
Usage: kubectl authentication for deployments
```

#### 4. CloudHub Credentials (Optional)
```
# Anypoint Username
Credential Type: Secret text
ID: anypoint-username
Secret: your-anypoint-username@company.com

# Anypoint Password
Credential Type: Secret text
ID: anypoint-password
Secret: your-anypoint-password

# Anypoint Organization
Credential Type: Secret text
ID: anypoint-org
Secret: your-org-id

# Anypoint Environment
Credential Type: Secret text
ID: anypoint-env
Secret: Development  # or Sandbox, Production
```

### Creating Credentials in Jenkins

#### Via Jenkins Web UI:
1. Navigate to **Manage Jenkins** → **Manage Credentials**
2. Click **System** → **Global credentials (unrestricted)**
3. Click **Add Credentials**
4. Fill in the details for each credential above
5. Click **OK**

#### Via Jenkins CLI:
```bash
# Create secret text credential
echo 'postgres123' | java -jar jenkins-cli.jar -s http://localhost:8080/ \
  create-credentials-by-xml system::system::jenkins _ < credentials-db-password.xml

# Create secret file credential
java -jar jenkins-cli.jar -s http://localhost:8080/ \
  create-credentials-by-xml system::system::jenkins _ < credentials-kubeconfig.xml
```

## 🏗️ Pipeline Trigger Methods

### 1. Automatic GitHub Webhook (Recommended)

#### Setup Webhook in GitHub:
1. Go to your repository → **Settings** → **Webhooks**
2. Click **Add webhook**
3. Configure:
   ```
   Payload URL: http://your-jenkins-url:8080/github-webhook/
   Content type: application/json
   Events: Just the push event
   Active: ✅
   ```

#### Test Webhook:
```bash
# Manual webhook trigger
curl -X POST http://localhost:8080/github-webhook/ \
  -H "Content-Type: application/json" \
  -d '{
    "ref": "refs/heads/main",
    "repository": {
      "full_name": "wedhazo/demo"
    }
  }'
```

### 2. Manual Pipeline Trigger

#### Via Jenkins Web UI:
1. Open Jenkins dashboard
2. Navigate to **mule-trading-app-pipeline**
3. Click **Build Now**

#### Via Jenkins API:
```bash
# Trigger build with authentication
curl -X POST http://localhost:8080/job/mule-trading-app-pipeline/build \
  --user admin:$JENKINS_API_TOKEN

# Check build status
curl -s http://localhost:8080/job/mule-trading-app-pipeline/lastBuild/api/json | jq .result
```

### 3. Scheduled Builds (Optional)

Add to Jenkinsfile:
```groovy
triggers {
    cron('H 2 * * *')  # Daily at 2 AM
    pollSCM('H/15 * * * *')  # Poll every 15 minutes
}
```

## 📊 Pipeline Stages Overview

### Stage Flow:
1. **Checkout** → Clone repository and set build variables
2. **MUnit Tests** → Run tests with ≥80% coverage enforcement
3. **Build JAR** → Create deployable Mule application
4. **Docker Build** → Create container image
5. **Docker Push** → Push to GitHub Container Registry
6. **Deploy to Kubernetes** → Deploy and verify rollout
7. **Health Check** → Verify application endpoints

### Expected Pipeline Duration:
- **Full Pipeline**: 8-12 minutes
- **MUnit Tests**: 2-3 minutes
- **Build & Docker**: 3-4 minutes
- **K8s Deployment**: 2-3 minutes
- **Health Check**: 1 minute

## ☸️ Kubernetes Deployment

### Prerequisites

#### 1. Cluster Access
```bash
# Verify kubectl access
kubectl cluster-info
kubectl get nodes

# Check namespaces
kubectl get namespaces | grep mule
```

#### 2. Required Secrets
```bash
# Create database secret manually (if needed)
kubectl create secret generic mule-db-secret \
  --from-literal=DB_PASSWORD="postgres123" \
  --namespace=mule-dev

# Create Docker registry secret (if using private registry)
kubectl create secret docker-registry ghcr-secret \
  --docker-server=ghcr.io \
  --docker-username=wedhazo \
  --docker-password="$GITHUB_TOKEN" \
  --namespace=mule-dev
```

### Deployment Process

#### 1. Automatic Deployment (via Jenkins)
The pipeline handles deployment automatically:
```bash
# Jenkins will execute:
kubectl apply -f k8s/deployment.yaml -n mule-dev
kubectl apply -f k8s/service.yaml -n mule-dev
kubectl rollout status deployment/mule-trading-app -n mule-dev --timeout=120s
```

#### 2. Manual Deployment
```bash
# Deploy specific version
DOCKER_TAG="abc1234"
kubectl set image deployment/mule-trading-app \
  mule-app=ghcr.io/wedhazo/demo:$DOCKER_TAG \
  -n mule-dev

# Apply all manifests
kubectl apply -f k8s/ -n mule-dev

# Wait for rollout
kubectl rollout status deployment/mule-trading-app -n mule-dev --timeout=300s
```

### Verification Commands

```bash
# Check deployment status
kubectl get deployments -n mule-dev
kubectl get pods -n mule-dev -l app=mule-trading-app
kubectl get services -n mule-dev

# Check application logs
kubectl logs -n mule-dev -l app=mule-trading-app --tail=50

# Test application endpoint
kubectl port-forward -n mule-dev svc/mule-app-service 8085:8081 &
curl -s http://localhost:8085/kb | jq .
```

### Scaling Operations

```bash
# Manual scaling
kubectl scale deployment mule-trading-app --replicas=3 -n mule-dev

# Check HPA status
kubectl get hpa -n mule-dev

# View scaling events
kubectl describe hpa mule-trading-app-hpa -n mule-dev
```

## 🔄 Manual Rollback Procedures

### Kubernetes Rollback

#### 1. Check Rollout History
```bash
# View deployment history
kubectl rollout history deployment/mule-trading-app -n mule-dev

# Example output:
# REVISION  CHANGE-CAUSE
# 1         Initial deployment
# 2         Updated image to abc1234
# 3         Updated image to def5678
```

#### 2. Rollback to Previous Version
```bash
# Rollback to immediately previous version
kubectl rollout undo deployment/mule-trading-app -n mule-dev

# Verify rollback
kubectl rollout status deployment/mule-trading-app -n mule-dev
```

#### 3. Rollback to Specific Revision
```bash
# Rollback to specific revision
kubectl rollout undo deployment/mule-trading-app --to-revision=2 -n mule-dev

# Check which image was deployed
kubectl describe deployment mule-trading-app -n mule-dev | grep Image
```

#### 4. Emergency Rollback Script
```bash
#!/bin/bash
# emergency-rollback.sh

set -e

NAMESPACE="mule-dev"
DEPLOYMENT="mule-trading-app"

echo "🚨 Emergency rollback initiated..."

# Get current revision
CURRENT_REVISION=$(kubectl rollout history deployment/$DEPLOYMENT -n $NAMESPACE | tail -n 1 | awk '{print $1}')
echo "Current revision: $CURRENT_REVISION"

# Rollback
kubectl rollout undo deployment/$DEPLOYMENT -n $NAMESPACE

# Wait for rollback to complete
kubectl rollout status deployment/$DEPLOYMENT -n $NAMESPACE --timeout=180s

# Verify pods are running
kubectl get pods -n $NAMESPACE -l app=mule-trading-app

# Test endpoint
kubectl port-forward -n $NAMESPACE svc/mule-app-service 8085:8081 &
sleep 5
if curl -f -s http://localhost:8085/kb > /dev/null; then
    echo "✅ Rollback successful - application responding"
else
    echo "❌ Rollback failed - application not responding"
    exit 1
fi

# Cleanup port forward
pkill -f "kubectl port-forward.*8085" || true

echo "🎯 Rollback completed successfully!"
```

### Docker Image Rollback

#### 1. List Available Images
```bash
# Check available images in registry
docker images ghcr.io/wedhazo/demo

# Or query GitHub Container Registry
curl -H "Authorization: Bearer $GITHUB_TOKEN" \
  "https://api.github.com/users/wedhazo/packages/container/demo/versions"
```

#### 2. Deploy Specific Image Version
```bash
# Deploy known good version
KNOWN_GOOD_TAG="abc1234"  # Replace with actual good tag
kubectl set image deployment/mule-trading-app \
  mule-app=ghcr.io/wedhazo/demo:$KNOWN_GOOD_TAG \
  -n mule-dev

# Wait for deployment
kubectl rollout status deployment/mule-trading-app -n mule-dev
```

### Jenkins Pipeline Rollback

#### 1. Rollback via Jenkins UI
1. Open failed build in Jenkins
2. Navigate to **Build History**
3. Find last successful build
4. Click **Replay** or **Rebuild**

#### 2. Rollback via Jenkins API
```bash
# Get last successful build number
LAST_SUCCESS=$(curl -s http://localhost:8080/job/mule-trading-app-pipeline/lastSuccessfulBuild/buildNumber)

# Trigger rebuild of successful version
curl -X POST http://localhost:8080/job/mule-trading-app-pipeline/build \
  --user admin:$JENKINS_API_TOKEN \
  --data "BUILD_NUMBER=$LAST_SUCCESS"
```

## ☁️ CloudHub Deployment (Alternative)

### Prerequisites

#### 1. Anypoint Platform Setup
```bash
# Install Anypoint CLI
npm install -g anypoint-cli@latest

# Verify installation
anypoint-cli --version
```

#### 2. Authentication Test
```bash
# Login test
anypoint-cli account login \
  --username your-username@company.com \
  --password your-password \
  --organization your-org-id
```

### CloudHub Deployment Process

#### 1. Automatic CloudHub Deploy (via Jenkins)
Uncomment the CloudHub stage in `Jenkinsfile.optimized`:

```groovy
stage('Deploy to CloudHub') {
    when {
        anyOf {
            branch 'main'
            branch 'develop'
        }
    }
    steps {
        echo "☁️ Deploying to CloudHub..."
        script {
            withCredentials([
                string(credentialsId: 'anypoint-username', variable: 'ANYPOINT_USERNAME'),
                string(credentialsId: 'anypoint-password', variable: 'ANYPOINT_PASSWORD'),
                string(credentialsId: 'anypoint-org', variable: 'ANYPOINT_ORG'),
                string(credentialsId: 'anypoint-env', variable: 'ANYPOINT_ENV'),
                string(credentialsId: 'db-password', variable: 'CH_DB_PASSWORD')
            ]) {
                sh '''
                    # Deploy to CloudHub
                    anypoint-cli runtime-mgr cloudhub-application deploy \
                        --environment $ANYPOINT_ENV \
                        --applicationName mule-trading-app \
                        --runtime 4.9.0 \
                        --workerSize 0.1 \
                        --workers 1 \
                        --region us-east-1 \
                        --property "mule.env=prod" \
                        --property "DB_PASSWORD=$CH_DB_PASSWORD" \
                        --autoStart \
                        target/*.jar
                '''
            }
        }
    }
}
```

#### 2. Manual CloudHub Deploy
```bash
# Set credentials
export ANYPOINT_USERNAME="your-username@company.com"
export ANYPOINT_PASSWORD="your-password"
export ANYPOINT_ORG="your-org-id"
export ANYPOINT_ENV="Development"

# Login
anypoint-cli account login \
  --username $ANYPOINT_USERNAME \
  --password $ANYPOINT_PASSWORD \
  --organization $ANYPOINT_ORG

# Deploy application
anypoint-cli runtime-mgr cloudhub-application deploy \
  --environment $ANYPOINT_ENV \
  --applicationName mule-trading-app \
  --runtime 4.9.0 \
  --workerSize 0.1 \
  --workers 1 \
  --region us-east-1 \
  --property "mule.env=prod" \
  --property "DB_PASSWORD=postgres123" \
  --autoStart \
  target/demo-1.0.0-SNAPSHOT-mule-application.jar
```

#### 3. CloudHub Management Commands
```bash
# Check application status
anypoint-cli runtime-mgr cloudhub-application describe \
  --environment $ANYPOINT_ENV \
  mule-trading-app

# View application logs
anypoint-cli runtime-mgr cloudhub-application tail-logs \
  --environment $ANYPOINT_ENV \
  mule-trading-app

# Stop application
anypoint-cli runtime-mgr cloudhub-application stop \
  --environment $ANYPOINT_ENV \
  mule-trading-app

# Start application
anypoint-cli runtime-mgr cloudhub-application start \
  --environment $ANYPOINT_ENV \
  mule-trading-app

# Delete application
anypoint-cli runtime-mgr cloudhub-application delete \
  --environment $ANYPOINT_ENV \
  mule-trading-app
```

### CloudHub Rollback

#### 1. Deploy Previous Version
```bash
# List application versions
anypoint-cli runtime-mgr cloudhub-application describe-json \
  --environment $ANYPOINT_ENV \
  mule-trading-app | jq .deployments

# Deploy specific JAR version
anypoint-cli runtime-mgr cloudhub-application deploy \
  --environment $ANYPOINT_ENV \
  --applicationName mule-trading-app \
  --runtime 4.9.0 \
  --property "mule.env=prod" \
  --property "DB_PASSWORD=postgres123" \
  path/to/previous-version.jar
```

## 🐛 Troubleshooting Deployments

### Common Issues & Solutions

#### 1. **Jenkins Credential Issues**
```bash
# Symptoms: "Credentials not found" or "Access denied"
# Solution: Verify credential IDs in Jenkins
curl -s http://localhost:8080/credentials/api/json | jq '.credentials[].id'

# Re-create credentials if needed
```

#### 2. **Docker Push Failures**
```bash
# Symptoms: "Authentication failed" or "Access denied"
# Solution: Verify GitHub token permissions
curl -H "Authorization: token $GITHUB_TOKEN" https://api.github.com/user

# Re-login to registry
echo $GITHUB_TOKEN | docker login ghcr.io -u wedhazo --password-stdin
```

#### 3. **Kubernetes Deployment Failures**
```bash
# Symptoms: "ImagePullBackOff" or "CrashLoopBackOff"
# Debug steps:
kubectl describe pod -n mule-dev -l app=mule-trading-app
kubectl logs -n mule-dev -l app=mule-trading-app

# Common fixes:
# - Check image exists: docker pull ghcr.io/wedhazo/demo:latest
# - Verify secrets: kubectl get secret mule-db-secret -n mule-dev -o yaml
# - Check resource limits in deployment.yaml
```

#### 4. **Health Check Failures**
```bash
# Symptoms: Pipeline succeeds but health check fails
# Debug steps:
kubectl port-forward -n mule-dev svc/mule-app-service 8085:8081 &
curl -v http://localhost:8085/kb

# Check application logs:
kubectl logs -n mule-dev -l app=mule-trading-app --tail=100
```

#### 5. **CloudHub Deployment Issues**
```bash
# Symptoms: "Application failed to start" or "Deployment timeout"
# Debug steps:
anypoint-cli runtime-mgr cloudhub-application tail-logs \
  --environment $ANYPOINT_ENV \
  mule-trading-app

# Common issues:
# - Incorrect application properties
# - Missing dependencies
# - Memory/CPU limits exceeded
```

### Recovery Procedures

#### Complete Pipeline Reset
```bash
#!/bin/bash
# complete-reset.sh

echo "🔄 Complete pipeline reset initiated..."

# 1. Stop current deployment
kubectl scale deployment mule-trading-app --replicas=0 -n mule-dev

# 2. Clean Jenkins workspace
curl -X POST http://localhost:8080/job/mule-trading-app-pipeline/doWipeOutWorkspace \
  --user admin:$JENKINS_API_TOKEN

# 3. Clean Docker images
docker image prune -a -f

# 4. Redeploy known good version
kubectl set image deployment/mule-trading-app \
  mule-app=ghcr.io/wedhazo/demo:latest \
  -n mule-dev

kubectl scale deployment mule-trading-app --replicas=2 -n mule-dev

# 5. Verify recovery
kubectl rollout status deployment/mule-trading-app -n mule-dev

echo "✅ Pipeline reset completed!"
```

## 📞 Emergency Contacts

### Escalation Matrix
- **Level 1**: Development Team → Slack #dev-team
- **Level 2**: DevOps Team → Slack #devops
- **Level 3**: Platform Team → Email devops-team@company.com
- **Level 4**: On-call Engineer → Phone +1-555-DEVOPS

### Emergency Procedures
1. **Immediate Rollback**: Use manual rollback commands above
2. **Service Degradation**: Scale down to single replica
3. **Complete Outage**: Activate disaster recovery plan
4. **Data Issues**: Contact DBA team immediately

---

## 📋 Quick Reference

### Essential Commands
```bash
# Pipeline trigger
curl -X POST http://localhost:8080/job/mule-trading-app-pipeline/build

# Check deployment
kubectl get pods -n mule-dev

# Rollback
kubectl rollout undo deployment/mule-trading-app -n mule-dev

# Health check
curl -s http://localhost:8085/kb | jq .

# View logs
kubectl logs -n mule-dev -l app=mule-trading-app --tail=50
```

### Credential IDs
- `db-password` - Database password
- `github-token` - GitHub PAT for registry
- `kubeconfig` - Kubernetes config file
- `anypoint-username` - CloudHub username
- `anypoint-password` - CloudHub password

---

**Need help?** Check the troubleshooting section above or contact the DevOps team.
