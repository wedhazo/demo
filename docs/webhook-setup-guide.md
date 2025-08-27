# Complete GitHub + Jenkins Integration Guide

## 🎯 **What We Need to Complete:**

### 1. **Push Changes to GitHub** (Required First)
```bash
# Add all our DevOps files to Git
git add .

# Commit with descriptive message
git commit -m "Add complete DevOps pipeline: Jenkins, Kubernetes, Docker, Monitoring"

# Push to your GitHub repository
git push origin main
```

### 2. **GitHub Webhook Setup** (2 minutes)

#### What is a Webhook?
A webhook is GitHub's way of saying "Hey Jenkins, someone just pushed code - start building!"

#### Steps:
1. **Go to your repository settings:**
   - Open: https://github.com/wedhazo/demo/settings/hooks
   - Click "Add webhook"

2. **Configure the webhook:**
   ```
   Payload URL: http://your-public-ip:8090/github-webhook/
   Content type: application/json
   Secret: (leave empty for now)
   
   Which events?
   ✅ Just the push event
   ✅ Pull requests (optional)
   
   Active: ✅ (checked)
   ```

3. **Important Note:** 
   - Since Jenkins is running locally (localhost:8090), GitHub can't reach it directly
   - For testing, we'll use Jenkins polling instead
   - For production, you'd need Jenkins on a public server or use ngrok

### 3. **Create Jenkins Pipeline Job** (5 minutes)

#### Steps:
1. **Open Jenkins:** http://localhost:8090
2. **Create New Job:**
   - Click "New Item"
   - Job name: `mule-trading-app-pipeline`
   - Type: "Pipeline"
   - Click "OK"

3. **Configure Pipeline:**
   ```
   General Tab:
   ✅ Description: "Mule Trading Application CI/CD Pipeline"
   ✅ GitHub project: https://github.com/wedhazo/demo
   
   Build Triggers:
   ✅ Poll SCM: H/5 * * * * (check every 5 minutes)
   
   Pipeline Tab:
   ✅ Definition: Pipeline script from SCM
   ✅ SCM: Git
   ✅ Repository URL: https://github.com/wedhazo/demo.git
   ✅ Branch Specifier: */main
   ✅ Script Path: Jenkinsfile
   ```

4. **Save and Test:**
   - Click "Save"
   - Click "Build Now"

## 🚀 **Alternative: Local Testing Setup**

Since your Jenkins is running locally, let's set up a polling-based integration:

### Jenkins Configuration for Local Development:
```groovy
// In Jenkinsfile, we already have:
triggers {
    pollSCM('H/5 * * * *')  // Check GitHub every 5 minutes
}
```

### Test the Integration:
1. Push changes to GitHub
2. Wait 5 minutes (or trigger manually)
3. Jenkins will detect changes and run pipeline
4. Pipeline will:
   - Build your Mule app
   - Create Docker image
   - Deploy to Kubernetes
   - Run tests
   - Send notifications

## 🔧 **For Production (Public Jenkins):**

If you want real webhooks (instant triggers), you need:

### Option A: Public Jenkins Server
```bash
# Deploy Jenkins on cloud provider
# Get public IP/domain
# Configure webhook with: http://your-jenkins-domain.com/github-webhook/
```

### Option B: Local Development with ngrok
```bash
# Install ngrok
ngrok http 8090

# Use ngrok URL in webhook:
# http://abc123.ngrok.io/github-webhook/
```

## ✅ **Current Status Check:**

Let me show you exactly what's configured and what we need to do next...
