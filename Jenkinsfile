pipeline {
    agent {
        kubernetes {
            yaml """
apiVersion: v1
kind: Pod
spec:
  containers:
  - name: maven
    image: maven:3.9.9-openjdk-17
    command:
    - cat
    tty: true
    volumeMounts:
    - name: docker-sock
      mountPath: /var/run/docker.sock
  - name: docker
    image: docker:latest
    command:
    - cat
    tty: true
    volumeMounts:
    - name: docker-sock
      mountPath: /var/run/docker.sock
  - name: kubectl
    image: bitnami/kubectl:latest
    command:
    - cat
    tty: true
  volumes:
  - name: docker-sock
    hostPath:
      path: /var/run/docker.sock
"""
        }
    }
    
    environment {
        ARTIFACTORY_URL = 'http://artifactory-service.artifactory.svc.cluster.local:8081'
        DOCKER_REGISTRY = 'artifactory-service.artifactory.svc.cluster.local:8082'
        MULE_APP_NAME = 'mule-trading-app'
        GIT_REPO = 'https://github.com/wedhazo/demo.git'
        KUBECONFIG = credentials('kubeconfig')
        ARTIFACTORY_CREDS = credentials('artifactory-credentials')
    }
    
    stages {
        stage('Checkout') {
            steps {
                script {
                    echo "🔄 Checking out code from GitHub..."
                    checkout scm
                }
            }
        }
        
        stage('Code Quality & Security') {
            parallel {
                stage('SonarQube Analysis') {
                    steps {
                        container('maven') {
                            script {
                                echo "🔍 Running SonarQube code analysis..."
                                sh '''
                                    mvn clean compile sonar:sonar \
                                        -Dsonar.projectKey=mule-trading-app \
                                        -Dsonar.host.url=http://sonarqube:9000 \
                                        -Dsonar.login=$SONAR_TOKEN
                                '''
                            }
                        }
                    }
                }
                
                stage('Security Scan') {
                    steps {
                        container('maven') {
                            script {
                                echo "🛡️ Running security vulnerability scan..."
                                sh '''
                                    mvn org.owasp:dependency-check-maven:check
                                '''
                            }
                        }
                    }
                }
            }
        }
        
        stage('Build & Test') {
            steps {
                container('maven') {
                    script {
                        echo "🏗️ Building Mule application..."
                        sh '''
                            mvn clean compile test package \
                                -Dmule.env=dev \
                                -DskipTests=false
                        '''
                        
                        // Archive test results
                        publishTestResults testResultsPattern: 'target/surefire-reports/*.xml'
                        
                        // Archive artifacts
                        archiveArtifacts artifacts: 'target/*.jar', fingerprint: true
                    }
                }
            }
        }
        
        stage('Build Docker Image') {
            steps {
                container('docker') {
                    script {
                        echo "🐳 Building Docker image..."
                        def imageTag = "${env.BUILD_NUMBER}-${env.GIT_COMMIT.take(7)}"
                        def imageName = "${DOCKER_REGISTRY}/${MULE_APP_NAME}:${imageTag}"
                        
                        sh """
                            docker build -f Dockerfile.simulator -t ${imageName} .
                            docker tag ${imageName} ${DOCKER_REGISTRY}/${MULE_APP_NAME}:latest
                        """
                        
                        // Push to Artifactory
                        withCredentials([usernamePassword(credentialsId: 'artifactory-credentials', 
                                                        usernameVariable: 'ARTIFACTORY_USER', 
                                                        passwordVariable: 'ARTIFACTORY_PASS')]) {
                            sh """
                                echo \$ARTIFACTORY_PASS | docker login ${DOCKER_REGISTRY} -u \$ARTIFACTORY_USER --password-stdin
                                docker push ${imageName}
                                docker push ${DOCKER_REGISTRY}/${MULE_APP_NAME}:latest
                            """
                        }
                        
                        env.DOCKER_IMAGE = imageName
                    }
                }
            }
        }
        
        stage('Deploy to Environments') {
            parallel {
                stage('Deploy to Dev') {
                    steps {
                        container('kubectl') {
                            script {
                                echo "🚀 Deploying to Development environment..."
                                sh '''
                                    kubectl set image deployment/mule-app mule-app=${DOCKER_IMAGE} -n mule-dev
                                    kubectl rollout status deployment/mule-app -n mule-dev --timeout=300s
                                '''
                            }
                        }
                    }
                }
                
                stage('Deploy to Test') {
                    when {
                        anyOf {
                            branch 'develop'
                            branch 'main'
                        }
                    }
                    steps {
                        container('kubectl') {
                            script {
                                echo "🧪 Deploying to Test environment..."
                                sh '''
                                    kubectl set image deployment/mule-app mule-app=${DOCKER_IMAGE} -n mule-test
                                    kubectl rollout status deployment/mule-app -n mule-test --timeout=300s
                                '''
                            }
                        }
                    }
                }
            }
        }
        
        stage('Integration Tests') {
            steps {
                container('maven') {
                    script {
                        echo "🧪 Running integration tests..."
                        sh '''
                            # Wait for deployment to be ready
                            sleep 30
                            
                            # Run integration tests against deployed application
                            mvn test -Dtest=IntegrationTest \
                                -Dmule.test.endpoint=http://mule-app-service.mule-dev.svc.cluster.local:8081
                        '''
                        
                        publishTestResults testResultsPattern: 'target/surefire-reports/*.xml'
                    }
                }
            }
        }
        
        stage('Performance Tests') {
            steps {
                container('maven') {
                    script {
                        echo "⚡ Running performance tests..."
                        sh '''
                            # Run JMeter performance tests
                            mvn jmeter:jmeter \
                                -DtestPlan=src/test/jmeter/load-test.jmx \
                                -DtargetHost=mule-app-service.mule-dev.svc.cluster.local \
                                -DtargetPort=8081
                        '''
                        
                        publishHTML([
                            allowMissing: false,
                            alwaysLinkToLastBuild: true,
                            keepAll: true,
                            reportDir: 'target/jmeter/reports',
                            reportFiles: 'index.html',
                            reportName: 'Performance Test Report'
                        ])
                    }
                }
            }
        }
        
        stage('Deploy to Production') {
            when {
                branch 'main'
            }
            steps {
                script {
                    echo "🎯 Requesting production deployment approval..."
                    
                    // Manual approval for production
                    input message: 'Deploy to Production?', 
                          ok: 'Deploy',
                          parameters: [
                              choice(name: 'ENVIRONMENT', 
                                     choices: ['prod'], 
                                     description: 'Target Environment')
                          ]
                    
                    container('kubectl') {
                        echo "🚀 Deploying to Production environment..."
                        sh '''
                            kubectl set image deployment/mule-app mule-app=${DOCKER_IMAGE} -n mule-prod
                            kubectl rollout status deployment/mule-app -n mule-prod --timeout=600s
                        '''
                        
                        // Run smoke tests in production
                        sh '''
                            sleep 30
                            curl -f http://mule-app-service.mule-prod.svc.cluster.local:8081/kb || exit 1
                        '''
                    }
                }
            }
        }
        
        stage('Notification') {
            steps {
                script {
                    echo "📧 Sending deployment notifications..."
                    
                    // Slack notification
                    slackSend(
                        channel: '#deployments',
                        color: 'good',
                        message: """
🚀 *Mule Trading App Deployed Successfully!*
• Build: #${env.BUILD_NUMBER}
• Branch: ${env.BRANCH_NAME}
• Commit: ${env.GIT_COMMIT.take(7)}
• Environment: ${params.ENVIRONMENT ?: 'dev,test'}
• Image: ${env.DOCKER_IMAGE}
• Duration: ${currentBuild.durationString}
                        """
                    )
                    
                    // Email notification
                    emailext(
                        subject: "✅ Mule App Deployment Successful - Build #${env.BUILD_NUMBER}",
                        body: """
                            <h2>Deployment Successful!</h2>
                            <p><strong>Application:</strong> Mule Trading App</p>
                            <p><strong>Build Number:</strong> ${env.BUILD_NUMBER}</p>
                            <p><strong>Branch:</strong> ${env.BRANCH_NAME}</p>
                            <p><strong>Commit:</strong> ${env.GIT_COMMIT}</p>
                            <p><strong>Duration:</strong> ${currentBuild.durationString}</p>
                            <p><strong>Docker Image:</strong> ${env.DOCKER_IMAGE}</p>
                        """,
                        to: 'dev-team@company.com'
                    )
                }
            }
        }
    }
    
    post {
        always {
            echo "🧹 Cleaning up workspace..."
            cleanWs()
        }
        
        failure {
            script {
                echo "❌ Pipeline failed! Sending failure notifications..."
                
                slackSend(
                    channel: '#deployments',
                    color: 'danger',
                    message: """
❌ *Mule Trading App Deployment Failed!*
• Build: #${env.BUILD_NUMBER}
• Branch: ${env.BRANCH_NAME}
• Stage: ${env.STAGE_NAME}
• Error: Check Jenkins logs for details
                    """
                )
                
                emailext(
                    subject: "❌ Mule App Deployment Failed - Build #${env.BUILD_NUMBER}",
                    body: "Deployment failed at stage: ${env.STAGE_NAME}. Please check Jenkins logs.",
                    to: 'dev-team@company.com'
                )
            }
        }
        
        success {
            echo "✅ Pipeline completed successfully!"
        }
    }
}
