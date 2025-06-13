#!/bin/bash

# Colima Kubernetes Persistent Setup Script with Klipper LoadBalancer
set -e

LOGFILE="/tmp/colima-k8s-persistent.log"
if [ -f "$LOGFILE" ]; then
    mv "$LOGFILE" "$LOGFILE.bak"
fi

# Load variables from .env (exported)
if [ -f ".env" ]; then
    set -a
    source .env
    set +a
fi
# Variables from .env are loaded as normal shell variables

echo "Colima runtime: $COLIMA_RUNTIME"

# Define your host path for the shared storage
if [[ -z "$K8S_POD_STORAGE_PATH" || "$K8S_POD_STORAGE_PATH" == "null" ]]; then
  echo "K8S_POD_STORAGE_PATH is not set. Please set it in .env.yaml."
  exit 1
fi
if [[ "$K8S_POD_STORAGE_PATH" == ~* ]]; then
  HOST_COMPOSE_PATH="${K8S_POD_STORAGE_PATH/#\~/$HOME}"
else
  HOST_COMPOSE_PATH="$K8S_POD_STORAGE_PATH"
fi
VM_COMPOSE_PATH="/compose" # This is where it will appear inside the Colima VM

# Graceful shutdown handler
cleanup() {
    echo "Gracefully shutting down Kubernetes cluster..."
    kubectl drain colima --ignore-daemonsets --delete-emptydir-data --force --grace-period=30 2>/dev/null || true
    echo "Stopping Colima k8s profile..."
    colima stop k8s
    echo "Cluster shutdown complete."
    exit 0
}

# Set up signal handlers
trap cleanup SIGTERM SIGINT SIGHUP SIGQUIT

# Function to ensure kubeconfig is properly set up
ensure_kubeconfig() {
    echo '--- Ensuring kubeconfig is properly configured ---'
    
    # Check if kubeconfig exists and has colima context
    if ! kubectl config get-contexts | grep -q "colima" 2>/dev/null; then
        echo "Extracting kubeconfig from Colima VM..."
        
        # Create .kube directory if it doesn't exist
        mkdir -p ~/.kube
        
        # Extract kubeconfig from Colima VM
        colima ssh --profile k8s -- cat /etc/rancher/k3s/k3s.yaml > ~/.kube/config
        
        # Set the context to colima
        kubectl config use-context default 2>/dev/null || true
        kubectl config rename-context default colima 2>/dev/null || true
        kubectl config use-context colima 2>/dev/null || true
    fi
    
    echo '--- Kubeconfig configured ---'
}

# Function to setup NGINX Ingress Controller with Klipper
setup_ingress_controller() {
    echo '--- Setting up NGINX Ingress Controller ---'
    
    # Check if ingress-nginx namespace exists
    if ! kubectl get namespace ingress-nginx &>/dev/null; then
        echo "Installing NGINX Ingress Controller..."
        
        # Add ingress-nginx helm repo if not already added
        helm repo add ingress-nginx https://kubernetes.github.io/ingress-nginx 2>/dev/null || true
        helm repo update
        
        # Install NGINX Ingress Controller as LoadBalancer (Klipper will handle it)
        helm install ingress-nginx ingress-nginx/ingress-nginx \
            -n ingress-nginx \
            --create-namespace \
            --set controller.ingressClassResource.default=true \
            --wait --timeout=300s
        
        echo "Waiting for ingress controller to be ready..."
        kubectl wait --namespace ingress-nginx \
            --for=condition=ready pod \
            --selector=app.kubernetes.io/component=controller \
            --timeout=300s
    else
        echo "NGINX Ingress Controller already installed"
    fi
    
    # Display services from all namespaces
    echo "--- Service across All namespaces ---"
    kubectl get svc -A
}

# Function to display access information
display_access_info() {
    echo '--- Access Information ---'
    
    # Get the Colima VM IP
    COLIMA_IP=$(kubectl get nodes -o jsonpath='{.items[0].status.addresses[?(@.type=="InternalIP")].address}')
    
    if [ ! -z "$COLIMA_IP" ]; then
        echo "Colima VM IP: $COLIMA_IP"
        echo "Direct HTTP access: http://$COLIMA_IP"
        echo "Direct HTTPS access: https://$COLIMA_IP"
        echo ""
        echo "For ingress-based services, add entries to /etc/hosts:"
        echo "$COLIMA_IP your-app.local"
        echo ""
        echo "No tunneling required! Services are directly accessible."
    fi
}

# Check if Colima k8s profile is running
if ! colima status k8s &>/dev/null; then
    echo 'Starting Colima k8s profile with network address and Kubernetes...'
    echo 'NOTE: Initial cluster creation may take several minutes, especially on first run.'
    echo 'No workloads or applications are preinstalled—this is a clean Kubernetes environment.'
    echo 'You will see status updates as each component becomes ready.'

    # Ensure the host directory exists before starting Colima
    mkdir -p "$HOST_COMPOSE_PATH"
    echo "Ensured host directory exists: $HOST_COMPOSE_PATH"

    # Start Colima with network-address flag for direct IP access and Kubernetes enabled
    colima start -p 50001:50001 -p 55080:55080 -p 55022:55022 \
        --profile k8s \
        --runtime "${COLIMA_RUNTIME:-containerd}" \
        --cpu 8 \
        --memory "${COLIMA_MEMORY:-8}" \
        --disk 100 \
        --mount-type virtiofs \
        --vm-type=vz \
        --vz-rosetta \
        --arch aarch64 \
        --network-address \
        --kubernetes \
        --mount "$HOST_COMPOSE_PATH:$VM_COMPOSE_PATH:w" # ADDED THIS LINE FOR MOUNTING!
    
    sleep 15
    
    echo 'Configuring proxy settings...'
    colima ssh --profile k8s -- sudo sh -c '
        set -o allexport
        if [ -f /etc/environment ]; then . /etc/environment; fi
        set +o allexport
    ' 2>/dev/null || echo "Proxy configuration completed"
    
else
    echo 'Colima k8s profile already running'
    echo 'No workloads or applications are preinstalled—this is a clean Kubernetes environment.'
    echo 'You will see status updates as each component becomes ready.'
fi

# Ensure kubeconfig is properly set up
ensure_kubeconfig

# Wait for Kubernetes to be fully ready
echo 'Waiting for Kubernetes to be ready...'
kubectl wait --for=condition=Ready nodes --all --timeout=300s

echo 'Kubernetes is ready. Installing ingress controller (NGINX) for external access to services...'

# Setup ingress controller
setup_ingress_controller

# Display access information
display_access_info

echo 'Setup complete. You can now deploy workloads using Helm charts or kubectl.'
echo 'For example, use the provided VSCode tasks to deploy services like Litellm, Milvus, OpenWebUI, MCPO, or Swiss.'

# Enhanced monitoring loop
while true; do
    echo "=== $(date) ==="
    
    echo '--- Colima Status ---'
    stdbuf -oL colima status k8s
    
    echo '--- Kubernetes Cluster Info ---'
    stdbuf -oL kubectl cluster-info 2>/dev/null || echo 'Kubernetes not ready yet'
    
    echo '--- Kubernetes Nodes ---'
    stdbuf -oL kubectl get nodes -o wide 2>/dev/null || echo 'Nodes not ready yet'
    
    echo '--- Node Resource Usage ---'
    stdbuf -oL kubectl top nodes 2>/dev/null || echo 'Resource usage metrics not available'
    
    echo '--- INGRESS Status ---'
    stdbuf -oL kubectl get ing -A 2>/dev/null || echo 'Ingress controller not ready'
    
    echo '--- Active Pods ---'
    stdbuf -oL kubectl get pods -A -o wide --field-selector=status.phase=Running 2>/dev/null || echo 'Pods not ready yet'
    
    echo '--- Service Status ---'
    stdbuf -oL kubectl get svc -A 2>/dev/null || echo 'Service controller not ready'
    
    sleep 15
done | tee -a "$LOGFILE"