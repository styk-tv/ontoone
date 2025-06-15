#!/bin/sh
#
# NOTE: If you update the destruction/cleanup resource reporting, you MUST also update the documentation
#       in BOTH k8s/start_chart.md and k8s/helmfile_destroy_flow.md.
# WHEN MAKING A CHANGE: Clearly request a doc patch to the linked step-logic in both .md files,
# specifying if logic was INVALIDATED, APPENDED, ADDED or REMOVED.
#
# Example:
#   "Doc update required: resource monitoring loop now prints PVC and ConfigMap on every iteration, not just in the final report. step X in start_chart.md and helmfile_destroy_flow.md MUST be updated/APPENDED accordingly."

# If not running under Bash, re-exec under Bash BEFORE any Bash-isms are parsed
if [ -z "$BASH_VERSION" ]; then
  if command -v bash >/dev/null 2>&1; then
    exec bash "$0" "$@"
    # exec replaces shell. The line below should never run
    echo "[ERROR] Failed to exec bash, aborting."
    exit 99
  else
    echo "[ERROR] Bash is required for this script. Please install bash and invoke with 'bash ./k8s/start_chart.sh ...'."
    exit 100
  fi
fi

set -e

sigint_destroy () {
  echo; if command -v figlet >/dev/null 2>&1; then figlet -f mini "SIGINT: DESTROY"; fi
  bash "$SCRIPT_DIR/helmfile_destroy.sh" "$PROJECT_NAME"
  exit 130
}
trap 'sigint_destroy' SIGINT

# --- Minimal, DRY, deterministic .env → pod env Helmfile deploy script ---
# This script is designed to deploy litellm with all .env values propagated to pod as env variables.
#
# --- Resources managed by this script (via Helmfile) ---
# Output of: helmfile -f litellm/helmfile.yaml.gotmpl list
#
# NAME   	NAMESPACE	ENABLED	INSTALLED	LABELS                                           	CHART                             	VERSION
# litellm	litellm  	true   	true     	chart:litellm-helm,name:litellm,namespace:litellm	oci://ghcr.io/berriai/litellm-helm	0.1.69
#

# Always in repo root for consistent context (exit on failure)
SCRIPT_DIR="$( cd "$( dirname "${BASH_SOURCE[0]}" )" &> /dev/null && pwd )"
REPO_ROOT=$(dirname "$SCRIPT_DIR")
cd "$REPO_ROOT" || { echo "[ERROR] Could not change to repository root: $REPO_ROOT"; exit 1; }

# Export all variables from .env so they are visible as environment to Helmfile templating
if [ -f .env ]; then
  echo "[INFO] Exporting variables from .env into environment (KEY-* values obfuscated):"
  export $(grep -v '^#' .env | xargs)
  grep -v '^#' .env | while read -r line; do
    key=$(echo "$line" | cut -d= -f1)
    value=$(echo "$line" | cut -d= -f2-)
    if [[ "$key" == *KEY* ]]; then
      # Mask all but first 3 chars
      if [[ -n "$value" ]]; then
        obf="${value:0:3}******"
      else
        obf=""
      fi
      echo "$key=$obf"
    else
      echo "$key=$value"
    fi
  done
else
  echo "[ERROR] Could not locate .env file in repo root."
  exit 1
fi

# Confirm that all expected env keys exist and are exported, especially for Helmfile/Go-template
echo "[DEBUG] Value of AZURE_API_BASE: ${AZURE_API_BASE:-NOT SET}"
echo "[DEBUG] Value of AZURE_API_KEY: ${AZURE_API_KEY:+***obfuscated***}"
echo "[DEBUG] Value of AZURE_API_VERSION: ${AZURE_API_VERSION:-NOT SET}"
echo "[DEBUG] Value of PROXY_MASTER_KEY: ${PROXY_MASTER_KEY:+***obfuscated***}"
MISSING=0
for v in AZURE_API_BASE AZURE_API_KEY AZURE_API_VERSION PROXY_MASTER_KEY; do
  if [[ -z "${!v:-}" ]]; then
    echo "[ERROR] Environment variable $v is not set; check .env syntax/case and rerun."
    MISSING=1
  fi
done
if [ "$MISSING" -ne 0 ]; then
  exit 2
fi

# Check Kubernetes cluster connectivity before proceeding
if ! kubectl version --request-timeout='6s' &>/dev/null; then
  echo "[ERROR] Unable to connect to the Kubernetes cluster."
  echo "Ensure you have Colima Kubernetes running and that it meets all requirements for this deployment."
  exit 10
fi

PROJECT_NAME="$1"
# ---- Start: Bash-only Attach Mode (SAFE FOR LEGACY STARTUP) ----
if [ -n "$BASH_VERSION" ]; then
  echo "[INFO] (Bash mode) Checking for existing litellm deployment in namespace '$PROJECT_NAME'..."
  HEALTHY_LITELLM_POD=""
  mapfile -t PODS < <(kubectl get pods -n "$PROJECT_NAME" -l "app=litellm" --no-headers 2>/dev/null | awk '$3 == "Running" && $2 ~ /^1\/1$/ {print $1}')
  if [ ${#PODS[@]} -gt 0 ]; then
    HEALTHY_LITELLM_POD="${PODS[0]}"
  fi

  if [ -n "$HEALTHY_LITELLM_POD" ]; then
    echo -e "\033[1;32m[INFO]\033[0m Detected a healthy running litellm deployment (pod: $HEALTHY_LITELLM_POD)."
    echo "[MODE] ATTACH: Attaching to logs for pod '$HEALTHY_LITELLM_POD'."
    echo "Press Ctrl+C to trigger graceful destruction (delete/release will start and monitor will display)."

    attach_destroy_mode=0

    cleanup_attach() {
      if [ $attach_destroy_mode -eq 0 ]; then
        attach_destroy_mode=1
        echo -e "\\n[MODE] DELETING: Triggering centralized destruction via helmfile_destroy.sh. Detaching from logs and handing off."
        bash "$SCRIPT_DIR/helmfile_destroy.sh" "$PROJECT_NAME"
        exit 130
      else
        echo "[INFO] Force exit requested."
        exit 99
      fi
    }

    trap cleanup_attach SIGINT

    # Attach to logs (will exit on signal due to trap)
    kubectl logs -f "$HEALTHY_LITELLM_POD" -n "$PROJECT_NAME"

    # If logs exit for any reason (e.g., pod gone), check if in cleanup or prompt exit
    if [ $attach_destroy_mode -eq 0 ]; then
      echo "[INFO] Log following ended, re-checking pod status."
      CURRENT_POD_COUNT=$(kubectl get pods -n "$PROJECT_NAME" -l "app=litellm" --no-headers 2>/dev/null | wc -l)
      if [ "$CURRENT_POD_COUNT" -eq 0 ]; then
        echo "[INFO] All litellm pods terminated. Exiting."
        exit 0
      else
        echo "[INFO] Pods still exist; you may re-run to attach again or trigger deletion."
        exit 7
      fi
    fi
    exit 0
  fi
fi
# ---- End Bash-only Attach Mode (SAFE FOR LEGACY STARTUP) ----

# Ensure wildcard TLS certificate secret exists in the target namespace before uninstalling
echo "[INFO] Refreshing wildcard TLS certificate secret in the '$PROJECT_NAME' namespace (if applicable)..."
"$SCRIPT_DIR/install-wildcard.sh" "$PROJECT_NAME"

echo -e "\033[1;36m[INFO]\033[0m Attempting to uninstall Helmfile-managed releases for project '$PROJECT_NAME' in namespace '$PROJECT_NAME'..."
# ==== Restored Deploy Logic (from original, after Bash attach mode) ====
# Ensure wildcard TLS certificate secret exists in the "$PROJECT_NAME" namespace before deploying
echo "[INFO] Creating/refreshing wildcard TLS certificate secret in the '$PROJECT_NAME' namespace..."
"$SCRIPT_DIR/install-wildcard.sh" "$PROJECT_NAME"

echo "[INFO] Applying Helmfile with dynamic .env → pod env mapping for '$PROJECT_NAME'..."
helmfile -f "./$PROJECT_NAME/helmfile.yaml.gotmpl" sync

# Post-deploy check: print actual envVars in the pod for selected keys.
echo "[INFO] Post-deploy: printing pod environment for key exported variables:"
POD=""
timeout_secs=60
waited=0

# Robust, project-agnostic pod lookup using configurable or auto-inferred label selector:
# Use the most robust pod selector based on actual pod label keys
# Try multiple selectors to find the correct pod label, fallback as needed
LABEL_SELECTOR="${POD_LABEL_SELECTOR:-app.kubernetes.io/name=$PROJECT_NAME}"
LABEL_FALLBACK_1="app.kubernetes.io/instance=$PROJECT_NAME"
LABEL_FALLBACK_2="app=$PROJECT_NAME"

resolve_pod_selector() {
  local labelsel="$1"
  local podname
  podname=$(kubectl get pods -n "$PROJECT_NAME" -l "$labelsel" -o jsonpath='{.items[0].metadata.name}' 2>/dev/null || true)
  if [[ -n "$podname" ]]; then
    LABEL_SELECTOR="$labelsel"
    echo "[DEBUG] Using pod selector: $LABEL_SELECTOR"
    POD="$podname"
    return 0
  fi
  return 1
}

POD=""
if ! resolve_pod_selector "$LABEL_SELECTOR"; then
  if ! resolve_pod_selector "$LABEL_FALLBACK_1"; then
    resolve_pod_selector "$LABEL_FALLBACK_2"
  fi
fi

# If user didn't override, fallback to common selectors if first fails.

POD_LOOKUP_CMD=(kubectl get pods -n "$PROJECT_NAME" -l "$LABEL_SELECTOR" -o jsonpath='{.items[0].metadata.name}')
POD_PHASE_CMD=(kubectl get pod -n "$PROJECT_NAME")

set -x
trap 'last_status=$?;
if [ "$last_status" = "130" ]; then # SIGINT/Ctrl+C
  echo "[INFO] SIGINT received, running destruction with helmfile_destroy.sh ..."
  figlet -f mini "SIGINT: DESTROY"
  bash "$SCRIPT_DIR/helmfile_destroy.sh" "$PROJECT_NAME"
  exit 130
fi
echo "[TRAP] Script exiting (line: $LINENO) with last status=$last_status"' EXIT
# Remove ERR trap—do not hard exit on expected pod lookup failure

echo "[DEBUG] PROJECT_NAME='$PROJECT_NAME'"
echo "[DEBUG] LABEL_SELECTOR='$LABEL_SELECTOR'"
echo "[DEBUG] timeout_secs='$timeout_secs'"
echo "[DEBUG] kubectl version:"
kubectl version --client=true || echo "[ERROR] Failed to get kubectl version"
set +x   # Disable bash trace before pod wait spinner; keep logs clean in console/CI.

echo "[INFO] Current pods+labels in namespace '$PROJECT_NAME':"
kubectl get pods -n "$PROJECT_NAME" --show-labels || echo "[WARN] Could not list pods."

echo "[INFO] Waiting up to $timeout_secs seconds for a pod matching '$LABEL_SELECTOR' in namespace '$PROJECT_NAME'..."

waited=0
POD=""
last_msg=""
SPINNER="/-\|"
spin_idx=0
firstfound=""
while : ; do
  set +e
  POD=$(kubectl get pods -n "$PROJECT_NAME" -l "$LABEL_SELECTOR" -o jsonpath='{.items[0].metadata.name}' 2>/dev/null || true)
  set -e
  if [[ -z "$POD" ]]; then
    spinchar=${SPINNER:spin_idx++%${#SPINNER}:1}
    echo -ne "\r[WAIT] ${spinchar} Awaiting pods:\n"
    kubectl get pods -n "$PROJECT_NAME" -o wide 2>/dev/null | tail -n +2 | column -t
    # Show all other main resources (like kubectl get all) to match destruction display
    kubectl get svc,ingress,deploy,sts,job -n "$PROJECT_NAME" 2>/dev/null || true
    sleep 2
    waited=$((waited + 2))
  else
    PHASE=$(kubectl get pod -n "$PROJECT_NAME" "$POD" -o jsonpath='{.status.phase}' 2>/dev/null || echo "Unknown")
    echo -ne "\r[INFO] Pod: $POD phase: $PHASE                       \n"
    if [[ -z "$firstfound" ]]; then
      echo "[INFO] Pod created: $POD. Attempting log tail (regardless of phase)..."
      firstfound=1
      # Try to tail logs even in Pending/Init, retry on error every 3s
      while true; do
        kubectl logs -f "$POD" -n "$PROJECT_NAME" 2>&1
        code=$?
        if [[ $code -eq 0 ]]; then
          break
        else
          echo "[INFO] Pod $POD not yet ready for logs. Re-attempt in 3s..."
          sleep 3
        fi
      done
    fi
    if [[ "$PHASE" == "Running" ]]; then
      echo "[SUCCESS] Pod $POD is Running (after ${waited}s)."
      break
    fi
    sleep 2
    waited=$((waited + 2))
  fi
  # Timeout logic removed: wait continues until user sends SIGINT (Ctrl+C)
done

set +x

echo "[INFO] Summary: All pod lookup logs:"
echo "$all_pod_lookup_logs"
echo "[INFO] Summary: All pod phase logs:"
echo "$all_pod_phase_logs"

if [[ -z "$POD" ]]; then
  echo "[ERROR] No pod was ever found matching selector '$LABEL_SELECTOR' in ns '$PROJECT_NAME'!"
  echo "[INFO] Fetching recent deployments and pod status in ns '$PROJECT_NAME':"
  kubectl get pods -n "$PROJECT_NAME" -o wide || echo "[ERROR] Could not list pods"
  kubectl get events -n "$PROJECT_NAME" --sort-by=.metadata.creationTimestamp | tail -20 || echo "[ERROR] Could not fetch events"
fi

if [[ -n "$POD" ]]; then
  echo "[INFO] Printing environment variables for pod: $POD"
  kubectl exec -n "$PROJECT_NAME" "$POD" -- env || true
  echo "[INFO] Tailing logs for pod: $POD (Ctrl+C to terminate, destruction & cleanup monitoring will begin)"
  tail_pid=""
  sigint_received=0

  # Monitor all resources until only PVCs and ConfigMaps remain
  monitor_resource_cleanup() {
    echo "[DESTRUCTION] Monitoring resource cleanup in namespace '$PROJECT_NAME' after destroy..."
    while true; do
      # List all resources except PVC and ConfigMap
      remaining=$(kubectl api-resources --verbs=list --namespaced -o name | grep -vE '^(persistentvolumeclaims|configmaps)$' \
        | xargs -I {} kubectl get {} -n "$PROJECT_NAME" --ignore-not-found --no-headers 2>/dev/null | grep -v '^No resources' | wc -l)
      if [[ "$remaining" -eq 0 ]]; then
        echo "[INFO] All resources have been cleaned up in namespace '$PROJECT_NAME'. Exiting monitor."
        break
      else
        echo "[INFO] Resources still found in '$PROJECT_NAME' (PVC/ConfigMaps may persist). Waiting..."
        kubectl get all -n "$PROJECT_NAME"
        kubectl get pvc,configmap -n "$PROJECT_NAME"
        sleep 5
      fi
    done

    echo "[INFO] Final report of persistent leftovers (PVCs and ConfigMaps):"
    kubectl get pvc,configmap -n "$PROJECT_NAME" 2>/dev/null || echo "[INFO] None found."
  }

  tail_and_monitor() {
    # Trap SIGINT/SIGTERM in this subshell to call cleanup properly
    trap 'perform_full_cleanup' SIGINT SIGTERM
    while true; do
      kubectl logs -f "$POD" -n "$PROJECT_NAME" &
      tail_pid=$!
      wait $tail_pid
      # When log process ends (pod restart or connection drop), briefly wait and re-attach unless SIGINT requested
      if [[ $sigint_received -eq 1 ]]; then
        break
      fi
      sleep 2
      echo "[INFO] Lost connection to logs, restarting log tail..."
    done
  }

  perform_full_cleanup() {
    if [ $sigint_received -eq 0 ]; then
      sigint_received=1
      if [[ -n "$tail_pid" ]]; then
        echo "[INFO] Killing log process..."
        kill "$tail_pid" 2>/dev/null || true
        wait "$tail_pid" 2>/dev/null || true
      fi
      echo "[DESTRUCTION] Initiating Helmfile destroy for '$PROJECT_NAME'..."
      helmfile -f "./$PROJECT_NAME/helmfile.yaml.gotmpl" -n "$PROJECT_NAME" --color destroy || true
      monitor_resource_cleanup
      exit 0
    fi
  }

  # Trap SIGINT/SIGTERM to ensure cleanup even if log tail hasn't started yet
  trap 'perform_full_cleanup' SIGINT SIGTERM

  # Immediately tail logs from the main pod when found; if it restarts, re-tail.
  while true; do
    echo
    echo "[INFO] Attaching to logs for pod: $POD (Ctrl+C to terminate and cleanup)"
    kubectl logs -f "$POD" -n "$PROJECT_NAME"
    code=$?
    if [[ $code -eq 0 ]]; then
      echo "[INFO] Log stream for pod $POD ended normally."
      # Check if pod still running or restart
      PHASE=$(kubectl get pod -n "$PROJECT_NAME" "$POD" -o jsonpath='{.status.phase}' 2>/dev/null)
      if [[ "$PHASE" != "Running" ]]; then
        echo "[WARN] Pod $POD is no longer Running (phase: $PHASE). Waiting for new pod..."
        break
      else
        echo "[INFO] Pod $POD still running, log tail lost? Reattaching in 2s..."
        sleep 2
      fi
    else
      echo "[WARN] Log tail failed for pod $POD (code $code), retrying in 2s..."
      sleep 2
    fi
  done

  # Cleanup on end or Ctrl+C
  perform_full_cleanup

fi  # End if [[ -n "$POD" ]]

  trap perform_full_cleanup SIGINT

  tail_and_monitor

  if [ $sigint_received -eq 0 ]; then
    echo "[INFO] kubectl logs exited normally, no termination requested."
  fi
else
  echo "[WARN] Could not find a $PROJECT_NAME pod to tail logs."
fi

# After kubectl logs ends, display resource summary automatically
echo

perform_full_cleanup() {
  echo "[DESTRUCTION] Initiating Helmfile destroy for '$PROJECT_NAME'..."
  helmfile -f "./$PROJECT_NAME/helmfile.yaml.gotmpl" -n "$PROJECT_NAME" --color destroy || true
  echo "[DESTRUCTION] Monitoring resource cleanup in namespace '$PROJECT_NAME' after destroy..."
  while true; do
    OUT=$(kubectl get all,ing -n "$PROJECT_NAME" 2>&1)
    echo "$OUT"
    kubectl get pvc,configmap -n "$PROJECT_NAME" 2>/dev/null || echo "[INFO] No PVC/ConfigMap found."
    if [[ "$OUT" =~ "No resources found" ]]; then
      REMAINING=$(echo "$OUT" | grep -v "No resources found" | grep -v '^$' | grep -v '^NAME' | wc -l)
      if [ "$REMAINING" -eq 0 ]; then
        echo "[INFO] All resources have been cleaned up in namespace '$PROJECT_NAME'. Exiting monitor."
        break
      fi
    fi
    sleep 5
    echo "[INFO] Refreshing resource list in namespace '$PROJECT_NAME'..."
  done
  exit 0
}

trap perform_full_cleanup SIGINT

echo "[INFO] Entering resource monitoring for namespace '$PROJECT_NAME': will exit only when all resources are gone."
while true; do
  OUT=$(kubectl get all,ing -n "$PROJECT_NAME" 2>&1)
  echo "$OUT"
  kubectl get pvc,configmap -n "$PROJECT_NAME" 2>/dev/null || echo "[INFO] No PVC/ConfigMap found."
  if [[ "$OUT" =~ "No resources found" ]]; then
    REMAINING=$(echo "$OUT" | grep -v "No resources found" | grep -v '^$' | grep -v '^NAME' | wc -l)
    if [ "$REMAINING" -eq 0 ]; then
      echo "[INFO] All resources have been cleaned up in namespace '$PROJECT_NAME'. Exiting monitor."
      break
    fi
  fi
  sleep 5
  echo "[INFO] Refreshing resource list in namespace '$PROJECT_NAME'..."
done

exit 0
# ==== End Restored Deploy Logic ====
if helmfile -f litellm/helmfile.yaml.gotmpl -n "$PROJECT_NAME" --color destroy; then
  echo -e "\033[1;32m[SUCCESS]\033[0m Helmfile destroy complete for namespace '$PROJECT_NAME'."
else
  echo -e "\033[1;31m[FAILED]\033[0m Helmfile destroy returned a non-zero exit status for namespace '$PROJECT_NAME'."
fi

cleanup() {
  echo
  echo -e "\033[1;33m[INFO]\033[0m Received exit signal, displaying Kubernetes resource status for troubleshooting..."
  echo
  echo -e "\033[1;33m[INFO]\033[0m Entering resource monitoring for namespace '$PROJECT_NAME': will exit only when all resources are gone."
  while true; do
    OUT=$(kubectl get all,ing -n "$PROJECT_NAME" 2>&1)
    echo -e "$OUT"
    kubectl get pvc,configmap -n "$PROJECT_NAME" 2>/dev/null || echo "[INFO] No PVC/ConfigMap found."
    if [[ "$OUT" =~ "No resources found" ]]; then
      REMAINING=$(echo "$OUT" | grep -v "No resources found" | grep -v '^$' | grep -v '^NAME' | wc -l)
      if [ "$REMAINING" -eq 0 ]; then
        echo -e "\033[1;32m[INFO]\033[0m All resources have been cleaned up in namespace '$PROJECT_NAME'. Exiting monitor."
        break
      fi
    fi
    sleep 5
    echo -e "\033[1;36m[INFO]\033[0m Refreshing resource list in namespace '$PROJECT_NAME'..."
  done
  exit 0
}
trap cleanup SIGINT SIGTERM

echo -e "\033[1;36m[INFO]\033[0m Monitoring resource cleanup in namespace '$PROJECT_NAME' after uninstall..."
while true; do
  OUT=$(kubectl get all,ing -n "$PROJECT_NAME" 2>&1)
  echo -e "$OUT"
  kubectl get pvc,configmap -n "$PROJECT_NAME" 2>/dev/null || echo "[INFO] No PVC/ConfigMap found."
  if [[ "$OUT" =~ "No resources found" ]]; then
    REMAINING=$(echo "$OUT" | grep -v "No resources found" | grep -v '^$' | grep -v '^NAME' | wc -l)
    if [ "$REMAINING" -eq 0 ]; then
      echo -e "\033[1;32m[INFO]\033[0m All resources have been cleaned up in namespace '$PROJECT_NAME'. Exiting monitor."
      break
    fi
  fi
  sleep 5
  echo -e "\033[1;36m[INFO]\033[0m Refreshing resource list in namespace '$PROJECT_NAME'..."
done

exit 0
  if [[ -n "$POD" ]]; then
    for key in AZURE_API_BASE AZURE_API_KEY AZURE_API_VERSION PROXY_MASTER_KEY HOST PORT; do
      value=$(kubectl exec -n litellm "$POD" -- printenv "$key" 2>/dev/null || echo "")
      if [[ "$key" == *KEY* ]]; then
        if [ -z "$value" ]; then
          obf=""
        else
          obf="${value:0:3}******"
        fi
        echo "$key=$obf"
      else
        echo "$key=$value"
      fi
    done
    # Extra: show pod phase and status
    phase=$(kubectl get pod -n litellm "$POD" -o jsonpath='{.status.phase}' 2>/dev/null)
    echo "POD: $POD Phase: $phase"
  else
    echo "[WARN] No litellm pods found in cluster or pod did not start."
  fi
  sleep 10
done
