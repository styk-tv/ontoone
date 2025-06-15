#!/bin/bash
# Start chart for an individual project using Helmfile with env-injected values.
# Usage: ./.vscode/start_chart.sh <project_folder> <repo_url> <chart_name> <chart_version>
# Example: ./.vscode/start_chart.sh litellm oci://ghcr.io/berriai/litellm-helm litellm-helm 0.1.694

set -e

if [ $# -lt 1 ]; then
  echo "Usage: $0 <project_folder> <repo_url> <chart_name> <chart_version>"
  exit 1
fi

PROJECT="$1"
REPO_URL="$2"
CHART_NAME="$3"
CHART_VERSION="$4"
SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
ROOT_DIR="$(cd "$SCRIPT_DIR/.." && pwd)"

# Source .env from project root
if [ -f "$ROOT_DIR/.env" ]; then
  set -a
  source "$ROOT_DIR/.env"
  set +a
  echo ".env loaded from $ROOT_DIR/.env"
else
  echo "No .env found in $ROOT_DIR"
fi

# Change to the project directory
cd "$ROOT_DIR/$PROJECT"

# Detect and use Go-templated helmfile if present, else fallback to static backdrop
if [ -f "./helmfile.yaml.gotmpl" ]; then
  HELMFILE_STATE="./helmfile.yaml.gotmpl"
elif [ -f "./helmfile.yaml" ]; then
  HELMFILE_STATE="./helmfile.yaml"
else
  echo "No helmfile.yaml or helmfile.yaml.gotmpl found in $(pwd)"
  exit 2
fi

# Set up environment variables for dynamic chart parameters
if [ -n "$REPO_URL" ]; then
  export CHART_REPO_URL="$REPO_URL"
fi
if [ -n "$CHART_NAME" ]; then
  export CHART_NAME="$CHART_NAME"
fi
if [ -n "$CHART_VERSION" ]; then
  export CHART_VERSION="$CHART_VERSION"
fi

# Run helmfile template (change to sync if you want to deploy)
echo "Running: helmfile template with state file $HELMFILE_STATE"
helmfile -f "$HELMFILE_STATE" template

# To deploy directly, comment above and uncomment:
# echo "Running: helmfile sync with state file $HELMFILE_STATE"
# helmfile -f "$HELMFILE_STATE" sync