#!/bin/bash
set -e

# This script is designed to manage the lifecycle of a Helm chart, including
# installation/upgrade and graceful shutdown upon receiving termination signals.
# It supports two modes of operation:
# 1. Local Chart Deployment: Assumes the chart is in ./<project_name>/helm/ and
#    values are in ./<project_name>/values.yaml (if present).
# 2. Remote Chart Deployment: Deploys a chart from a specified Helm repository URL,
#    chart name, and version. Your project-level values.yaml is still applied.

# Usage for local chart:
#   ./k8s/start_chart.sh <project_name>
#   Example: ./k8s/start_chart.sh agentzero
#
# Usage for remote chart:
#   ./k8s/start_chart.sh <project_name> <helm_repo_url> <helm_chart_name> <helm_chart_version>
#   Example: ./k8s/start_chart.sh my-app https://charts.bitnami.com/bitnami nginx-ingress 1.2.3

# Assign arguments
PROJECT_NAME="$1"
HELM_REPO_URL=""
HELM_CHART_NAME=""
HELM_CHART_VERSION=""
# HELM_REPO_ALIAS removed as a direct argument

# --- Argument Validation and Mode Determination ---
if [ "$#" -eq 1 ]; then
    # Local chart deployment (only project name provided)
    CHART_SOURCE_TYPE="local"
elif [ "$#" -eq 4 ]; then
    # Remote chart deployment (project name + repo URL + chart name + chart version)
    CHART_SOURCE_TYPE="remote"
    HELM_REPO_URL="$2"
    HELM_CHART_NAME="$3"
    HELM_CHART_VERSION="$4"
else
    echo "Error: Invalid number of arguments."
    echo "Usage for local chart: $0 <project_name>"
    echo "Usage for remote chart: $0 <project_name> <helm_repo_url> <helm_chart_name> <helm_chart_version>"
    exit 1
fi

# --- Ensure we are in the repository root for consistent pathing ---
# This makes the script robust against where it is called from.
# SCRIPT_DIR gets the absolute path to the directory containing this script.
SCRIPT_DIR="$( cd "$( dirname "${BASH_SOURCE[0]}" )" &> /dev/null && pwd )"
# REPO_ROOT assumes this script is in a subdirectory (e.g., ./k8s) of the repo root.
REPO_ROOT=$(dirname "$SCRIPT_DIR")

# Change to the repository root. All subsequent relative paths will be based on this.
cd "$REPO_ROOT" || { echo "Error: Could not change to repository root: $REPO_ROOT"; exit 1; }

echo "Current working directory (after changing to repo root): $(pwd)"

# --- Derive Common Parameters ---
# For generality, we assume the namespace and release name are the same as the project name.
NAMESPACE="$PROJECT_NAME"
RELEASE_NAME="$PROJECT_NAME"

# Path to the project-level values.yaml file (always assumed for overrides)
VALUES_FILE="./${PROJECT_NAME}/values.yaml"

echo "Resolved NAMESPACE: $NAMESPACE"
echo "Resolved RELEASE_NAME: $RELEASE_NAME"
echo "Resolved VALUES_FILE: $VALUES_FILE"

# Global variable to store the PID of the kubectl logs process, for cleanup
LOG_PID=""

# --- Cleanup Function for Graceful Shutdown ---
# This function is called when a termination signal is received.
cleanup() {
    echo "" # Newline for cleaner output
    echo "--- Caught termination signal. Initiating graceful shutdown for namespace: '$NAMESPACE' ---"

    # Terminate the background kubectl logs process if it exists
    if [ -n "$LOG_PID" ] && ps -p "$LOG_PID" > /dev/null; then
        echo "Terminating background log streaming process (PID: $LOG_PID)..."
        kill "$LOG_PID" || true # Send SIGTERM, allow failure if already gone
        wait "$LOG_PID" 2>/dev/null || true # Wait for it to clean up, suppress errors
    fi

    # Attempt to uninstall the Helm release
    helm uninstall "$RELEASE_NAME" -n "$NAMESPACE"
    if [ $? -ne 0 ]; then
        echo "Warning: Helm uninstall command failed for '$RELEASE_NAME' in '$NAMESPACE'. Resources might need manual cleanup."
    fi

    # Loop to check for resource removal and display status for the specific namespace
    while true; do
        echo "--- Current resources in namespace '$NAMESPACE' (waiting for graceful removal) ---"
        # Get all namespaced resources (all, ing), PVCs in the namespace, and PVs bound to this namespace's PVCs.
        # Namespaced resources
        local ns_resources=$(kubectl get all,ing -n "$NAMESPACE" -o custom-columns=KIND:.kind,NAME:.metadata.name,STATUS:.status.phase,NAMESPACE:.metadata.namespace --sort-by=.kind 2>&1)
        # PVCs in the namespace
        local pvc_resources=$(kubectl get pvc -n "$NAMESPACE" -o custom-columns=KIND=PVC,NAME:.metadata.name,STATUS:.status.phase,NAMESPACE:.metadata.namespace 2>/dev/null)
        # PVs bound to PVCs in this namespace
        local pv_resources=$(kubectl get pv -o custom-columns=KIND=PV,NAME:.metadata.name,STATUS:.status.phase,CLAIM_NAMESPACE:.spec.claimRef.namespace 2>/dev/null | awk -v ns="$NAMESPACE" 'NR==1 || $4==ns')

        # Combine and filter out headers and empty lines
        local current_resources_output=$( (echo "$ns_resources"; echo "$pvc_resources"; echo "$pv_resources") )
        local filtered_output=$(echo "$current_resources_output" | grep -vE '(^KIND|^No resources found|^$)')

        if [ -z "$filtered_output" ]; then
            echo "--- All monitored resources in namespace '$NAMESPACE' have been gracefully removed. Shutdown complete. ---"
            echo "All resources removed. Task is gone."
            # Optional: keep the terminal open for review if running interactively
            if [ -t 1 ]; then
                read -n 1 -s -r -p "Press any key to close..."
                echo
            else
                # If not running interactively (e.g., VSCode task close), pause briefly so output is visible
                sleep 2
            fi
            break # Exit the loop as resources are gone
        else
            # Display the remaining resources
            echo "$filtered_output"
            echo "Waiting for graceful removal..."
            sleep 3 # Wait for 3 seconds before re-checking
        fi
    done
    exit 0 # Exit the script after successful cleanup
}

# --- Trap Signals ---
# Register the cleanup function to be called upon receiving specific signals.
# SIGTERM: Standard termination signal (e.g., from `kill` command or orchestrator)
# SIGINT: Interrupt signal (e.g., Ctrl+C)
# SIGHUP: Hangup signal (e.g., terminal session disconnected)
# SIGQUIT: Quit signal (e.g., Ctrl+\)
trap cleanup SIGTERM SIGINT SIGHUP SIGQUIT

echo "--- Script started for project: '$PROJECT_NAME' (Namespace: '$NAMESPACE', Release: '$RELEASE_NAME') ---"

# --- Execute K8s Wildcard Installation Script (if it exists) ---
# This step is included as per the original task's structure.
# It's assumed this script handles cluster-wide configurations like wildcard certificates.
# It will receive the namespace (which is the project name in this generic setup).
if [ -f "./k8s/install-wildcard.sh" ]; then
    echo "Executing ./k8s/install-wildcard.sh for namespace: '$NAMESPACE'..."
    sh ./k8s/install-wildcard.sh "$NAMESPACE"
    if [ $? -ne 0 ]; then
        echo "Error: The 'install-wildcard.sh' script failed. Exiting."
        exit 1 # Exit if the wildcard script fails
    fi
else
    echo "Warning: './k8s/install-wildcard.sh' not found. Skipping this step."
fi

# --- Helm Chart Installation/Upgrade ---
echo "Proceeding with Helm chart upgrade/installation for release: '$RELEASE_NAME'..."

# Conditional arguments for Helm based on values file presence
VALUES_ARG=""
if [ -f "$VALUES_FILE" ]; then
    echo "Using project-level values file: '$VALUES_FILE'."
    VALUES_ARG="--values \"$VALUES_FILE\""
else
    echo "Warning: Project-level values file '$VALUES_FILE' not found. Using values defined within the Helm chart only."
fi

if [ "$CHART_SOURCE_TYPE" == "remote" ]; then
    if [[ "$HELM_REPO_URL" == oci://* ]]; then
        # OCI registry: use the OCI URL directly, do not add as repo
        CHART_REF="$HELM_REPO_URL"
        echo "Deploying OCI Helm chart: '$HELM_CHART_NAME', version: '$HELM_CHART_VERSION' from OCI registry: '$HELM_REPO_URL'"
        helm upgrade --install "$RELEASE_NAME" "$CHART_REF" \
          --version "$HELM_CHART_VERSION" \
          --namespace "$NAMESPACE" \
          --create-namespace \
          --wait \
          $VALUES_ARG
    else
        # Classic repo logic
        # Auto-derive a simple repo name for 'helm repo add'
        REPO_ALIAS=$(echo "$HELM_REPO_URL" | sed -e 's|https\?://||' -e 's|[^a-zA-Z0-9]|-|g' | cut -c1-20)
        if [ -z "$REPO_ALIAS" ]; then REPO_ALIAS="remote-helm-repo"; fi # Fallback if URL parsing fails

        echo "Deploying remote Helm chart: '$HELM_CHART_NAME', version: '$HELM_CHART_VERSION' from repository: '$HELM_REPO_URL' using auto-generated alias: '$REPO_ALIAS'"

        echo "Adding/updating Helm repository '$REPO_ALIAS' at '$HELM_REPO_URL'..."
        helm repo add "$REPO_ALIAS" "$HELM_REPO_URL" 2>/dev/null || true # Suppress error if repo already exists
        helm repo update

        # Construct the full chart reference (e.g., "myrepo/nginx-ingress")
        CHART_REF="$REPO_ALIAS/$HELM_CHART_NAME"

        # Helm upgrade command for remote chart
        HELM_OUTPUT=$(helm upgrade --install "$RELEASE_NAME" "$CHART_REF" \
          --version "$HELM_CHART_VERSION" \
          --namespace "$NAMESPACE" \
          --create-namespace \
          --wait \
          $VALUES_ARG 2>&1)
        HELM_EXIT_CODE=$?
    fi
else
    # Local chart deployment
    LOCAL_CHART_PATH="./${PROJECT_NAME}/helm" # Re-derive for clarity in this block
    echo "Deploying local Helm chart from: '$LOCAL_CHART_PATH'"

    if [ ! -d "$LOCAL_CHART_PATH" ]; then
        echo "Error: Local Helm chart path '$LOCAL_CHART_PATH' not found for project '$PROJECT_NAME'. Exiting."
        exit 1
    fi

    # Helm upgrade command for local chart
    helm upgrade --install "$RELEASE_NAME" "$LOCAL_CHART_PATH" \
      --namespace "$NAMESPACE" \
      --create-namespace \
      --wait \
      $VALUES_ARG
fi

if [ "${HELM_EXIT_CODE:-0}" -ne 0 ]; then
    echo "Warning: Helm upgrade/install command failed for '$RELEASE_NAME'."
    echo "$HELM_OUTPUT"
    # Check for specific ingress conflict error
    if echo "$HELM_OUTPUT" | grep -q "admission webhook.*host.*already defined"; then
        echo "Detected ingress host/path conflict. The Ingress resource already exists in this namespace."
        echo "This is a Kubernetes resource conflict, not a script error."
        echo "Keeping the script alive for inspection, logging, and cleanup. Please resolve the conflict manually if needed."
        # Do not exit with error; continue to log streaming and main loop
    else
        # Check if the Helm release exists (even if upgrade failed)
        if helm status "$RELEASE_NAME" -n "$NAMESPACE" > /dev/null 2>&1; then
            echo "Warning: Helm upgrade/install failed, but release '$RELEASE_NAME' exists in namespace '$NAMESPACE'."
            echo "Continuing to attach to existing resources and stream logs."
        else
            echo "No existing Helm release found for '$RELEASE_NAME' in namespace '$NAMESPACE'. Exiting."
            exit 1
        fi
    fi
else
    echo "Helm chart '$RELEASE_NAME' successfully deployed in namespace '$NAMESPACE'."
fi

# --- Add a small delay for Kubernetes to fully register resources ---
echo "Waiting 5 seconds for Kubernetes resources to become fully discoverable..."
sleep 5

# --- Stream Application Logs in background and keep script alive to catch signals ---
echo "Attempting to find the primary deployment for release '$RELEASE_NAME' in namespace '$NAMESPACE' for log streaming..."

# Find the deployment name
DEPLOYMENT_NAME=$(kubectl get deployments -n "$NAMESPACE" -l "app.kubernetes.io/instance=$RELEASE_NAME" -o jsonpath='{.items[0].metadata.name}' 2>/dev/null)

if [ -z "$DEPLOYMENT_NAME" ]; then
    echo "Warning: No primary deployment found with label 'app.kubernetes.io/instance=$RELEASE_NAME' in namespace '$NAMESPACE'."
    echo "No logs will be streamed, but the script will remain active for signal handling and cleanup."
else
    echo "Streaming logs for deployment '$DEPLOYMENT_NAME' in namespace '$NAMESPACE'. Press Ctrl+C to initiate graceful shutdown."
    # Run kubectl logs in the background and store its PID
    kubectl logs -f "deployment/$DEPLOYMENT_NAME" -n "$NAMESPACE" &
    LOG_PID=$! # Capture the PID of the background kubectl logs process
fi

# The main script now remains in the foreground and can catch signals.
# Keep the script active indefinitely to allow signal traps to work.
echo "Script is now running in the foreground, waiting for termination signals (Ctrl+C to initiate graceful shutdown)."
while true; do
    sleep 5 # Keep the script alive and responsive
done

# The script will continue running until a signal is caught,
# at which point the cleanup function will be invoked.
