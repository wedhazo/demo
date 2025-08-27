#!/bin/bash

# Mule Application Kubernetes Deployment Script
# Usage: ./deploy.sh [dev|test|prod|all]

set -e

ENVIRONMENT=${1:-dev}
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
K8S_DIR="$SCRIPT_DIR/k8s"

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

log() {
    echo -e "${GREEN}[$(date +'%Y-%m-%d %H:%M:%S')] $1${NC}"
}

warn() {
    echo -e "${YELLOW}[$(date +'%Y-%m-%d %H:%M:%S')] WARNING: $1${NC}"
}

error() {
    echo -e "${RED}[$(date +'%Y-%m-%d %H:%M:%S')] ERROR: $1${NC}"
    exit 1
}

info() {
    echo -e "${BLUE}[$(date +'%Y-%m-%d %H:%M:%S')] INFO: $1${NC}"
}

# Check if kubectl is available
check_kubectl() {
    if ! command -v kubectl &> /dev/null; then
        error "kubectl is not installed or not in PATH"
    fi
    
    if ! kubectl cluster-info &> /dev/null; then
        error "Cannot connect to Kubernetes cluster"
    fi
    
    log "kubectl is available and connected to cluster"
}

# Check if docker is available
check_docker() {
    if ! command -v docker &> /dev/null; then
        error "Docker is not installed or not in PATH"
    fi
    
    log "Docker is available"
}

# Build Docker image
build_image() {
    log "Building Docker image..."
    
    cd "$SCRIPT_DIR"
    
    # Build the application first
    log "Building Mule application..."
    mvn clean package -DskipTests -Dmule.env=dev
    
    # Build Docker image
    log "Building Docker image: mule-trading-app:latest"
    docker build -t mule-trading-app:latest .
    
    # Tag for different environments
    docker tag mule-trading-app:latest mule-trading-app:dev
    docker tag mule-trading-app:latest mule-trading-app:test
    docker tag mule-trading-app:latest mule-trading-app:prod
    
    log "Docker image built successfully"
}

# Deploy to specific environment
deploy_environment() {
    local env=$1
    
    info "Deploying to $env environment..."
    
    # Create namespace if it doesn't exist
    log "Creating/updating namespace for $env..."
    kubectl apply -f "$K8S_DIR/namespaces.yaml"
    
    # Apply PostgreSQL initialization
    log "Applying PostgreSQL initialization scripts..."
    kubectl apply -f "$K8S_DIR/postgres-init.yaml" -n "mule-$env"
    
    # Deploy environment-specific resources
    case $env in
        dev)
            log "Deploying development environment..."
            kubectl apply -f "$K8S_DIR/dev-environment.yaml"
            sleep 30  # Wait for PostgreSQL to be ready
            kubectl apply -f "$K8S_DIR/mule-app-dev.yaml"
            ;;
        test)
            log "Deploying test environment..."
            kubectl apply -f "$K8S_DIR/test-environment.yaml"
            sleep 30
            kubectl apply -f "$K8S_DIR/mule-app-test.yaml"
            ;;
        prod)
            log "Deploying production environment..."
            kubectl apply -f "$K8S_DIR/prod-environment.yaml"
            sleep 30
            kubectl apply -f "$K8S_DIR/mule-app-prod.yaml"
            ;;
        *)
            error "Invalid environment: $env. Use dev, test, or prod"
            ;;
    esac
    
    # Apply ingress
    log "Applying ingress configuration..."
    kubectl apply -f "$K8S_DIR/ingress.yaml"
    
    # Wait for deployment to be ready
    log "Waiting for deployment to be ready..."
    kubectl wait --for=condition=available --timeout=300s deployment/mule-app -n "mule-$env"
    
    # Get service information
    info "Deployment completed for $env environment"
    kubectl get pods -n "mule-$env" -l app=mule-app
    kubectl get svc -n "mule-$env"
}

# Test deployment
test_deployment() {
    local env=$1
    
    info "Testing $env deployment..."
    
    # Get service endpoint
    local service_ip=$(kubectl get svc mule-app-service -n "mule-$env" -o jsonpath='{.status.loadBalancer.ingress[0].ip}' 2>/dev/null || echo "")
    
    if [ -z "$service_ip" ]; then
        # If LoadBalancer IP is not available, use port-forward for testing
        warn "LoadBalancer IP not available, using port-forward for testing..."
        kubectl port-forward svc/mule-app-service 8081:8081 -n "mule-$env" &
        local port_forward_pid=$!
        sleep 5
        
        # Test the endpoint
        if curl -f http://localhost:8081/kb >/dev/null 2>&1; then
            log "✅ $env environment is responding correctly"
        else
            error "❌ $env environment is not responding"
        fi
        
        # Kill port-forward
        kill $port_forward_pid 2>/dev/null || true
    else
        # Test with LoadBalancer IP
        if curl -f "http://$service_ip:8081/kb" >/dev/null 2>&1; then
            log "✅ $env environment is responding correctly at $service_ip"
        else
            error "❌ $env environment is not responding at $service_ip"
        fi
    fi
}

# Cleanup environment
cleanup_environment() {
    local env=$1
    
    warn "Cleaning up $env environment..."
    
    kubectl delete -f "$K8S_DIR/mule-app-$env.yaml" --ignore-not-found=true
    kubectl delete -f "$K8S_DIR/${env}-environment.yaml" --ignore-not-found=true
    kubectl delete configmap postgres-init-script -n "mule-$env" --ignore-not-found=true
    
    log "Cleanup completed for $env environment"
}

# Show help
show_help() {
    echo "Mule Application Kubernetes Deployment Script"
    echo ""
    echo "Usage: $0 [COMMAND] [ENVIRONMENT]"
    echo ""
    echo "Commands:"
    echo "  deploy [env]    Deploy to specific environment (dev|test|prod|all)"
    echo "  test [env]      Test specific environment deployment"
    echo "  cleanup [env]   Cleanup specific environment"
    echo "  build           Build Docker image"
    echo "  help            Show this help"
    echo ""
    echo "Environments:"
    echo "  dev             Development environment"
    echo "  test            Test environment"
    echo "  prod            Production environment"
    echo "  all             All environments"
    echo ""
    echo "Examples:"
    echo "  $0 deploy dev       # Deploy to development"
    echo "  $0 deploy all       # Deploy to all environments"
    echo "  $0 test prod        # Test production deployment"
    echo "  $0 cleanup test     # Cleanup test environment"
}

# Main execution
main() {
    local command=${1:-deploy}
    local environment=${2:-dev}
    
    case $command in
        deploy)
            check_kubectl
            check_docker
            build_image
            
            if [ "$environment" = "all" ]; then
                for env in dev test prod; do
                    deploy_environment $env
                    test_deployment $env
                done
            else
                deploy_environment $environment
                test_deployment $environment
            fi
            ;;
        test)
            check_kubectl
            test_deployment $environment
            ;;
        cleanup)
            check_kubectl
            if [ "$environment" = "all" ]; then
                for env in dev test prod; do
                    cleanup_environment $env
                done
            else
                cleanup_environment $environment
            fi
            ;;
        build)
            check_docker
            build_image
            ;;
        help|--help|-h)
            show_help
            ;;
        *)
            error "Unknown command: $command. Use 'help' for usage information."
            ;;
    esac
}

# Run main function with all arguments
main "$@"
