#!/bin/bash


set -e

PROJECT_NAME="$1"
if [[ -z "$PROJECT_NAME" ]]; then
  echo "[ERROR] Usage: $0 <project_name>"
  exit 1
fi

echo "[DESTRUCTION] Initiating Helmfile destroy for '$PROJECT_NAME'..."
helmfile -f "./$PROJECT_NAME/helmfile.yaml.gotmpl" -n "$PROJECT_NAME" --color destroy || true

echo "[DESTRUCTION] Monitoring resource cleanup in namespace '$PROJECT_NAME' after destroy..."
while true; do
  OUT=$(kubectl get all,ing -n "$PROJECT_NAME" 2>&1)
  echo "$OUT"
  # Ignore PVCs and ConfigMaps in main deletion check
  NON_PERSISTING=$(echo "$OUT" | grep -Ev 'No resources found|^NAME|^persistentvolumeclaim|^configmap' | wc -l)
  if [[ "$OUT" =~ "No resources found" ]] || [[ $NON_PERSISTING -eq 0 ]]; then
    if command -v figlet >/dev/null 2>&1; then figlet -f mini "STORAGE INFO"; fi
    echo "[INFO] All non-stateful resources have been cleaned up in namespace '$PROJECT_NAME'. Showing persistent storage and configmaps:"
    kubectl get pvc,configmap -n "$PROJECT_NAME" 2>/dev/null || echo "[INFO] No PVC/ConfigMap found."
    break
  fi
  sleep 5
done

echo "[INFO] Destruction and reporting complete for namespace '$PROJECT_NAME'."
exit 0