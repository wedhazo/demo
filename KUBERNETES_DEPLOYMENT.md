# Mule Trading Application - Kubernetes Deployment

This repository contains the complete Kubernetes deployment configuration for the Mule Trading Application with multi-environment support (dev/test/prod) and high availability.

## 🏗️ Architecture Overview

```
┌─────────────────┐    ┌─────────────────┐    ┌─────────────────┐
│   Development   │    │      Test       │    │   Production    │
│   Environment   │    │   Environment   │    │   Environment   │
├─────────────────┤    ├─────────────────┤    ├─────────────────┤
│ • 2 Mule Pods   │    │ • 3 Mule Pods   │    │ • 5 Mule Pods   │
│ • 1 PostgreSQL  │    │ • 1 PostgreSQL  │    │ • 2 PostgreSQL  │
│ • Basic Scaling │    │ • Load Testing  │    │ • HA + Failover │
│ • HTTP Access   │    │ • Rate Limiting │    │ • HTTPS + TLS   │
└─────────────────┘    └─────────────────┘    └─────────────────┘
```

## 🚀 Quick Start

### Prerequisites

1. **Kubernetes Cluster** (local or cloud)
   ```bash
   # For local development, install minikube or kind
   minikube start --memory=8192 --cpus=4
   # OR
   kind create cluster --config=kind-config.yaml
   ```

2. **Docker** installed and running
3. **kubectl** configured to access your cluster
4. **NGINX Ingress Controller** (optional, for external access)

### One-Command Deployment

```bash
# Deploy to all environments
./deploy.sh deploy all

# Deploy to specific environment
./deploy.sh deploy dev
./deploy.sh deploy test
./deploy.sh deploy prod
```

## 📦 Deployment Components

### 🔧 Infrastructure Components

| Component | Dev | Test | Prod | Description |
|-----------|-----|------|------|-------------|
| **Mule App Pods** | 2 | 3 | 5 | API application instances |
| **PostgreSQL** | 1 | 1 | 2 | Database (HA in prod) |
| **Load Balancer** | ❌ | ✅ | ✅ | External traffic distribution |
| **Auto Scaling** | ✅ | ✅ | ✅ | HPA based on CPU/Memory |
| **SSL/TLS** | ❌ | ❌ | ✅ | HTTPS encryption |
| **Monitoring** | Basic | Enhanced | Full | Prometheus + Alerting |

### 🌐 Environment Configuration

#### Development (`mule-dev` namespace)
- **Purpose**: Local development and basic testing
- **Resources**: Minimal resource allocation
- **Access**: `http://mule-dev.local/kb`
- **Database**: Single PostgreSQL instance
- **Scaling**: 2-5 pods (CPU: 70%, Memory: 80%)

#### Test (`mule-test` namespace)
- **Purpose**: Integration testing and load testing
- **Resources**: Medium resource allocation
- **Access**: `http://mule-test.local/kb`
- **Database**: Single PostgreSQL with persistent storage
- **Scaling**: 3-8 pods (CPU: 60%, Memory: 70%)
- **Features**: Rate limiting, load balancing

#### Production (`mule-prod` namespace)
- **Purpose**: Production workloads
- **Resources**: High resource allocation
- **Access**: `https://mule-prod.local/kb`
- **Database**: PostgreSQL StatefulSet with replication
- **Scaling**: 5-20 pods (CPU: 50%, Memory: 60%)
- **Features**: SSL/TLS, pod anti-affinity, PDB, security contexts

## 🔄 Failover and High Availability

### Application Level Failover
```yaml
# Multiple replicas with rolling updates
replicas: 5  # Production
strategy:
  type: RollingUpdate
  rollingUpdate:
    maxSurge: 2
    maxUnavailable: 1
```

### Database Failover
```yaml
# Production PostgreSQL with replication
replicas: 2  # Primary + Replica
env:
  - name: POSTGRES_REPLICATION_MODE
    value: "master"
```

### Pod Distribution
```yaml
# Anti-affinity to spread pods across nodes
affinity:
  podAntiAffinity:
    preferredDuringSchedulingIgnoredDuringExecution:
    - weight: 100
      podAffinityTerm:
        labelSelector:
          matchExpressions:
          - key: app
            operator: In
            values: [mule-app]
        topologyKey: kubernetes.io/hostname
```

### Health Checks
```yaml
livenessProbe:
  httpGet:
    path: /kb
    port: 8081
  initialDelaySeconds: 90
  periodSeconds: 30
  failureThreshold: 3

readinessProbe:
  httpGet:
    path: /kb
    port: 8081
  initialDelaySeconds: 45
  periodSeconds: 10
  failureThreshold: 3
```

## 📊 Monitoring and Observability

### Metrics Collection
- **Prometheus** scrapes application metrics
- **Grafana** dashboards for visualization
- **Alertmanager** for critical alerts

### Key Metrics Monitored
- Application uptime and response time
- CPU and memory usage
- Database connection health
- HTTP request rates and errors
- Pod restart counts

### Alerts Configured
- Application down (1 minute)
- High memory usage (>80% for 5 minutes)
- High CPU usage (>80% for 5 minutes)
- Database connection failures

## 🛠️ Operations

### Deploy to Specific Environment
```bash
# Development
./deploy.sh deploy dev

# Test
./deploy.sh deploy test

# Production
./deploy.sh deploy prod
```

### Test Deployments
```bash
# Test specific environment
./deploy.sh test dev
./deploy.sh test test
./deploy.sh test prod
```

### Scale Applications
```bash
# Manual scaling
kubectl scale deployment mule-app --replicas=10 -n mule-prod

# Check HPA status
kubectl get hpa -n mule-prod
```

### Access Applications
```bash
# Port forward for local access
kubectl port-forward svc/mule-app-service 8081:8081 -n mule-dev

# Test the API
curl http://localhost:8081/kb
```

### View Logs
```bash
# Application logs
kubectl logs -f deployment/mule-app -n mule-prod

# Database logs
kubectl logs -f statefulset/postgres-prod -n mule-prod
```

### Database Operations
```bash
# Connect to database
kubectl exec -it postgres-prod-0 -n mule-prod -- psql -U postgres -d ft_trading

# Backup database
kubectl exec postgres-prod-0 -n mule-prod -- pg_dump -U postgres ft_trading > backup.sql
```

## 🔧 Configuration Management

### Environment Variables
Each environment has its own ConfigMap and Secret:

```yaml
# Example: Development ConfigMap
apiVersion: v1
kind: ConfigMap
metadata:
  name: mule-app-config
  namespace: mule-dev
data:
  MULE_ENV: "dev"
  DB_HOST: "postgres-dev.mule-dev.svc.cluster.local"
  DB_PORT: "5432"
  DB_NAME: "ft_trading"
  DB_USER: "postgres"
```

### Secrets Management
```bash
# Update database password
kubectl create secret generic mule-app-secrets \
  --from-literal=DB_PASSWORD=new_password \
  --namespace=mule-prod \
  --dry-run=client -o yaml | kubectl apply -f -
```

## 🧪 Testing

### Load Testing
```bash
# Install hey (HTTP load testing tool)
go install github.com/rakyll/hey@latest

# Test development environment
hey -n 1000 -c 10 http://mule-dev.local/kb

# Test production environment
hey -n 10000 -c 50 https://mule-prod.local/kb
```

### Integration Testing
```bash
# Run integration tests against test environment
./deploy.sh test test

# Verify all endpoints are working
for env in dev test prod; do
  echo "Testing $env environment..."
  curl -f "http://mule-$env.local/kb" && echo "✅ $env OK" || echo "❌ $env FAILED"
done
```

## 🚨 Troubleshooting

### Common Issues

1. **Pods stuck in Pending state**
   ```bash
   kubectl describe pod <pod-name> -n <namespace>
   # Check for resource constraints or node affinity issues
   ```

2. **Database connection failures**
   ```bash
   # Check if PostgreSQL is running
   kubectl get pods -n mule-prod -l app=postgres-prod
   
   # Check connectivity
   kubectl exec -it mule-app-xxx -n mule-prod -- nslookup postgres-prod
   ```

3. **Ingress not working**
   ```bash
   # Check ingress controller
   kubectl get pods -n ingress-nginx
   
   # Check ingress configuration
   kubectl describe ingress mule-app-ingress-prod -n mule-prod
   ```

### Debug Commands
```bash
# Get all resources in namespace
kubectl get all -n mule-prod

# Check events
kubectl get events -n mule-prod --sort-by='.lastTimestamp'

# Check resource usage
kubectl top pods -n mule-prod
kubectl top nodes
```

## 🔒 Security

### Network Policies
- Isolated namespaces
- Database access restricted to application pods
- Ingress traffic filtered

### Pod Security
- Non-root containers
- Read-only root filesystem where possible
- Security contexts applied
- Resource limits enforced

### Secrets Management
- Database passwords stored in Kubernetes Secrets
- TLS certificates managed by cert-manager
- Environment-specific secret isolation

## 📈 Performance Tuning

### JVM Settings by Environment
- **Dev**: `-Xms512m -Xmx1024m`
- **Test**: `-Xms768m -Xmx1536m`
- **Prod**: `-Xms1024m -Xmx2048m -XX:+UseG1GC`

### Database Tuning
- Connection pooling
- Query optimization
- Index management
- Replication configuration

### Kubernetes Tuning
- Resource requests and limits
- HPA configuration
- Pod disruption budgets
- Node affinity rules

## 🔄 CI/CD Integration

This deployment can be integrated with CI/CD pipelines:

```yaml
# Example GitLab CI integration
deploy_dev:
  stage: deploy
  script:
    - ./deploy.sh deploy dev
  environment:
    name: development
    url: http://mule-dev.local

deploy_test:
  stage: deploy
  script:
    - ./deploy.sh deploy test
  environment:
    name: testing
    url: http://mule-test.local
  when: manual

deploy_prod:
  stage: deploy
  script:
    - ./deploy.sh deploy prod
  environment:
    name: production
    url: https://mule-prod.local
  when: manual
  only:
    - main
```

## 🆘 Support

For issues and support:
1. Check the troubleshooting section
2. Review Kubernetes events and logs
3. Check monitoring dashboards
4. Verify resource availability

## 📚 Additional Resources

- [Kubernetes Documentation](https://kubernetes.io/docs/)
- [MuleSoft Documentation](https://docs.mulesoft.com/)
- [PostgreSQL Kubernetes Operator](https://postgres-operator.readthedocs.io/)
- [Prometheus Operator](https://prometheus-operator.dev/)

---

**Happy Deploying! 🚀**
