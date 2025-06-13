#!/bin/bash
set -e

# --- Minimal, DRY, deterministic .env → pod env Helmfile deploy script ---
# This script is designed to deploy litellm with all .env values propagated to pod as env variables.

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

PROJECT_NAME="$1"
if [ "$PROJECT_NAME" != "litellm" ]; then
  echo "[ERROR] Only 'litellm' project is supported in this mode."
  exit 1
fi

echo "[INFO] Applying Helmfile with dynamic .env → pod env mapping for '$PROJECT_NAME'..."
helmfile -f ./litellm/helmfile.yaml.gotmpl sync

# Post-deploy check: print actual envVars in the pod for selected keys.
echo "[INFO] Post-deploy: printing pod environment for key exported variables:"
POD=""
timeout_secs=60
waited=0
# wait for pod to be Running
while [[ -z "$POD" ]] || [[ "$(kubectl get pod -n litellm "$POD" -o jsonpath='{.status.phase}' 2>/dev/null)" != "Running" ]]; do
  POD=$(kubectl get pods -n litellm -l app.kubernetes.io/name=litellm -o jsonpath='{.items[0].metadata.name}' 2>/dev/null)
  if [[ -z "$POD" ]]; then
    sleep 2
    waited=$((waited + 2))
  else
    phase=$(kubectl get pod -n litellm "$POD" -o jsonpath='{.status.phase}' 2>/dev/null)
    if [[ "$phase" == "Running" ]]; then
      break
    fi
    sleep 2
    waited=$((waited + 2))
  fi
  if [ "$waited" -ge "$timeout_secs" ]; then
    echo "[WARN] Timeout waiting for litellm pod to be Running."
    break
  fi
done
if [[ -n "$POD" ]]; then
  for key in AZURE_API_BASE AZURE_API_KEY AZURE_API_VERSION PROXY_MASTER_KEY HOST PORT; do
    value=$(kubectl exec -n litellm "$POD" -- printenv "$key" 2>/dev/null || echo "")
    # Obfuscate anything with 'KEY' in the variable name (show XXX****)
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
else
  echo "[WARN] No litellm pods found in cluster after deploy or pod did not start in 60s."
fi
