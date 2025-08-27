# GitHub Integration Setup
## 1. Repository Settings

### Webhook Configuration
- **Payload URL**: `http://jenkins-service.jenkins.svc.cluster.local:8080/github-webhook/`
- **Content Type**: `application/json`
- **Events**: 
  - Push events
  - Pull request events
  - Release events

### Branch Protection Rules
```yaml
# .github/branch-protection.yml
main:
  required_status_checks:
    strict: true
    contexts:
      - "jenkins/build"
      - "jenkins/test"
      - "jenkins/security-scan"
  enforce_admins: true
  required_pull_request_reviews:
    required_approving_review_count: 2
    dismiss_stale_reviews: true
    require_code_owner_reviews: true
  restrictions: null

develop:
  required_status_checks:
    strict: true
    contexts:
      - "jenkins/build"
      - "jenkins/test"
  enforce_admins: false
  required_pull_request_reviews:
    required_approving_review_count: 1
    dismiss_stale_reviews: true
```

## 2. GitHub Actions Integration (Alternative/Complementary)

### Build Workflow
```yaml
# .github/workflows/build.yml
name: Build and Test
on:
  push:
    branches: [ main, develop ]
  pull_request:
    branches: [ main ]

jobs:
  build:
    runs-on: ubuntu-latest
    steps:
    - uses: actions/checkout@v3
    
    - name: Set up JDK 17
      uses: actions/setup-java@v3
      with:
        java-version: '17'
        distribution: 'temurin'
    
    - name: Cache Maven dependencies
      uses: actions/cache@v3
      with:
        path: ~/.m2
        key: ${{ runner.os }}-m2-${{ hashFiles('**/pom.xml') }}
    
    - name: Build with Maven
      run: mvn clean compile test package
    
    - name: Upload artifacts
      uses: actions/upload-artifact@v3
      with:
        name: mule-application
        path: target/*.jar
    
    - name: Trigger Jenkins Pipeline
      run: |
        curl -X POST \
          -H "Authorization: Bearer ${{ secrets.JENKINS_TOKEN }}" \
          "http://jenkins-service.jenkins.svc.cluster.local:8080/job/mule-trading-app/build"
```

## 3. Environment Variables
```bash
# GitHub Repository Secrets
JENKINS_TOKEN=<jenkins-api-token>
ARTIFACTORY_USER=admin
ARTIFACTORY_PASSWORD=<password>
SONAR_TOKEN=<sonarqube-token>
SLACK_WEBHOOK_URL=<slack-webhook>
KUBE_CONFIG=<base64-encoded-kubeconfig>
```

## 4. Integration Benefits

### Continuous Integration
- **Automated Builds**: Every push triggers Jenkins pipeline
- **Pull Request Validation**: Automated testing before merge
- **Branch Protection**: Enforced quality gates
- **Code Reviews**: Required approvals for production deployments

### Artifact Management (JFrog)
- **Docker Registry**: Store application container images
- **Maven Repository**: Cache and manage dependencies
- **Build Promotion**: Move artifacts through environments
- **Security Scanning**: Vulnerability analysis of dependencies

### Deployment Pipeline
- **GitOps Workflow**: Git commits trigger deployments
- **Environment Promotion**: dev → test → prod
- **Rollback Capability**: Quick revert to previous versions
- **Blue/Green Deployments**: Zero-downtime releases
