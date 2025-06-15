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

  # Check if all that is left are configmaps and/or PVCs
  NON_PERSISTING=$(echo "$OUT" | grep -Ev 'No resources found|^NAME|^persistentvolumeclaim|^configmap' | wc -l)
  PVC_OR_CONFIGMAP_LEFT=$(echo "$OUT" | grep -E '^persistentvolumeclaim|^configmap' | wc -l)
  TOTAL_RESOURCE_LINES=$(echo "$OUT" | grep -Ev '^NAME|No resources found' | wc -l)

  # If only pvc/configmap objects left (or nothing left at all), quit waiting and show final storage/configmap report
  if [[ "$OUT" =~ "No resources found" ]] || { [[ $NON_PERSISTING -eq 0 ]] && [[ $TOTAL_RESOURCE_LINES -eq $PVC_OR_CONFIGMAP_LEFT ]]; }; then
    if command -v figlet >/dev/null 2>&1; then figlet -f mini "STORAGE INFO"; fi
    echo "[INFO] All non-stateful resources have been cleaned up in namespace '$PROJECT_NAME'. Showing persistent storage and configmaps:"
    kubectl get pvc,configmap -n "$PROJECT_NAME" 2>/dev/null || echo "[INFO] No PVC/ConfigMap found."
    break
  fi
  sleep 5
done

echo "[INFO] Destruction and reporting complete for namespace '$PROJECT_NAME'."
exit 0