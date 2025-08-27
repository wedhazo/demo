# GitHub + Jenkins Integration Setup

## 🔧 Current Status:
- ✅ Git Repository: https://github.com/wedhazo/demo.git
- ✅ Jenkins: Running on http://localhost:8090
- ✅ Jenkinsfile: Created in repository root
- ⚠️ Changes Need to be Committed and Pushed

## 📝 Step-by-Step Integration:

### 1. Commit and Push Changes
```bash
# Add all new DevOps files
git add .

# Commit the changes
git commit -m "Add complete DevOps pipeline with Jenkins, K8s, and monitoring"

# Push to GitHub
git push origin main
```

### 2. Configure Jenkins Pipeline

#### A. Create Jenkins Job
1. Open Jenkins: http://localhost:8090
2. Click "New Item"
3. Enter name: "mule-trading-app-pipeline"
4. Select "Pipeline" project type
5. Click "OK"

#### B. Configure Pipeline
1. **General Tab:**
   - ✅ GitHub project: https://github.com/wedhazo/demo
   - ✅ Description: "Mule Trading Application CI/CD Pipeline"

2. **Build Triggers Tab:**
   - ✅ GitHub hook trigger for GITScm polling
   - ✅ Poll SCM: H/5 * * * * (every 5 minutes)

3. **Pipeline Tab:**
   - ✅ Definition: Pipeline script from SCM
   - ✅ SCM: Git
   - ✅ Repository URL: https://github.com/wedhazo/demo.git
   - ✅ Branch: */main
   - ✅ Script Path: Jenkinsfile

### 3. GitHub Webhook Configuration

#### A. Repository Settings
1. Go to: https://github.com/wedhazo/demo/settings/hooks
2. Click "Add webhook"
3. Configure:
   - **Payload URL**: http://jenkins-service.jenkins.svc.cluster.local:8080/github-webhook/
   - **Content type**: application/json
   - **Secret**: (optional, for security)
   - **Events**: 
     - ✅ Just the push event
     - ✅ Pull requests
     - ✅ Releases

#### B. Branch Protection (Recommended)
1. Go to: https://github.com/wedhazo/demo/settings/branches
2. Add rule for `main` branch:
   - ✅ Require status checks before merging
   - ✅ Require branches to be up to date
   - ✅ Status checks: jenkins/build, jenkins/test

### 4. Required Credentials in Jenkins

#### A. Add GitHub Credentials
1. Jenkins → Manage Jenkins → Credentials
2. Add these credentials:
   - **GitHub Token**: For repository access
   - **Kubeconfig**: For Kubernetes deployments
   - **Artifactory**: For artifact storage
   - **DockerHub**: For image registry

#### B. Install Required Plugins
```
- GitHub Plugin
- Pipeline Plugin
- Kubernetes Plugin
- Docker Pipeline Plugin
- Blue Ocean Plugin
- Artifactory Plugin
```

## 🔄 Automated Workflow:

```
Developer Push/PR → GitHub → Webhook → Jenkins → Pipeline Execution:
1. Checkout code
2. Maven build & test
3. Docker image build
4. Push to Artifactory
5. Deploy to Dev (automatic)
6. Integration tests
7. Deploy to Test (on main/develop)
8. Manual approval for Prod
9. Deploy to Production
10. Notifications (Slack/Email)
```

## ✅ Verification Steps:

1. **Test Webhook**: Make a small commit and push
2. **Check Jenkins**: Pipeline should trigger automatically
3. **Monitor Builds**: View progress in Blue Ocean
4. **Verify Deployments**: Check Kubernetes pods after build

## 🚨 Current Integration Status:

- 🔧 **Repository**: ✅ Connected (wedhazo/demo)
- 📋 **Jenkinsfile**: ✅ Created
- 🔨 **Jenkins**: ✅ Running
- 📦 **Artifactory**: ✅ Deployed
- ⚠️ **Git Sync**: Files need to be pushed
- ⚠️ **Webhook**: Needs manual configuration in GitHub
- ⚠️ **Jenkins Job**: Needs to be created manually
