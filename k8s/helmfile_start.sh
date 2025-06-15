#!/bin/bash

# Robust, unified start/deploy + multi-pod log tailer for any project with pre-reqs, validation, and explicit banners

set -e

PROJECT_NAME="$1"
if [[ -z "$PROJECT_NAME" ]]; then
  echo "[ERROR] Usage: $0 <project_name>"
  exit 1
fi

SCRIPT_DIR="$( cd "$( dirname "${BASH_SOURCE[0]}" )" &> /dev/null && pwd )"
REPO_ROOT=$(dirname "$SCRIPT_DIR")
cd "$REPO_ROOT" || { echo "[ERROR] Could not change to repository root: $REPO_ROOT"; exit 1; }

sigint_destroy() {
  echo
  if command -v figlet >/dev/null 2>&1; then
    figlet -f mini "SIGINT: DESTROY"
  fi
  bash "$SCRIPT_DIR/helmfile_destroy.sh" "$PROJECT_NAME"
  exit 130
}
trap 'sigint_destroy' SIGINT

# 1. ENV CHECK
if command -v figlet >/dev/null 2>&1; then
  figlet -f mini "ENV CHECK"
fi
echo "[ENV] Exporting/checking .env for required deploy variables"
if [ -f .env ]; then
  export $(grep -v '^#' .env | xargs)
  MISSING=0
  for v in AZURE_API_BASE AZURE_API_KEY AZURE_API_VERSION PROXY_MASTER_KEY; do
    if [[ -z "${!v:-}" ]]; then
      echo "[ERROR] Environment variable $v is not set; check .env syntax/case."
      MISSING=1
    fi
  done
  if [ "$MISSING" -ne 0 ]; then
    exit 2
  fi
else
  echo "[ERROR] .env not found!"
  exit 1
fi

# 2. KUBE CONNECT
if command -v figlet >/dev/null 2>&1; then
  figlet -f mini "KUBE CONNECT"
fi
echo "[KUBE] Checking cluster connectivity..."
if ! kubectl version --request-timeout='6s' &>/dev/null; then
  echo "[ERROR] Unable to connect to the Kubernetes cluster."
  exit 10
fi

# 3. CERTS/PRE-REQS
if command -v figlet >/dev/null 2>&1; then
  figlet -f mini "CERTS / PRE-REQS"
fi
echo "[PRE-REQ] Refreshing wildcard TLS cert secret in '$PROJECT_NAME' (if applicable)..."
"$SCRIPT_DIR/install-wildcard.sh" "$PROJECT_NAME"

# 4. DEPLOY
if command -v figlet >/dev/null 2>&1; then
  figlet -f mini "DEPLOY"
fi
echo "[DEPLOY] Running helmfile sync for project '$PROJECT_NAME'..."
helmfile -f "./$PROJECT_NAME/helmfile.yaml.gotmpl" -n "$PROJECT_NAME" --color sync

# 5. LOGS (STERN)
if command -v figlet >/dev/null 2>&1; then
  figlet -f mini "LOGS (STERN)"
fi
echo "[LOG] Tailing all pod logs in '$PROJECT_NAME' (Ctrl+C triggers full cleanup)..."
command -v stern >/dev/null 2>&1 || { echo "[ERROR] stern not found (please install stern: https://github.com/stern/stern)"; exit 4; }

# Tail logs for all pods in the namespace
stern -n "$PROJECT_NAME" .

echo "[INFO] stern process exited. No further log streaming."