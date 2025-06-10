# Litellm Project

This folder contains the Helm chart and configuration for the Litellm deployment.

## Tasks

| Task Label              | How to Launch | Command / Script | Description |
|-------------------------|---------------|------------------|-------------|
| 11 litellm.onto.one     | Task Manager  | sh ./k8s/start_chart.sh litellm oci://ghcr.io/berriai/litellm-helm litellm-helm 0.1.694 | Launches the Litellm Helm chart into Kubernetes |
| 12 litellm.onto.one EXEC| Task Manager  | kubectl exec -it ... -n litellm -- /bin/sh | Opens a shell directly into the Litellm pod |

## Configuration Files

- **values.yaml**  
  Main configuration file for the Litellm Helm chart. Edit this file to set deployment parameters, environment variables, and other options for your Litellm instance.

- **original-values.yaml**  
  Reference file containing the original/default values for the Helm chart. Use this as a guide to see all possible configuration options available for Litellm.

## Usage

1. Use the Task Manager extension in VSCode to launch the "11 litellm.onto.one" task to deploy Litellm.
2. Use the "12 litellm.onto.one EXEC" task to open a shell in the running Litellm pod for troubleshooting or direct interaction.
---

**Breadcrumb:** [Home (../README.md)](../README.md) > [TASKS](../TASKS.md) > [PROJECTS](../PROJECTS.md) > litellm

[← PROJECTS.md](../PROJECTS.md) | [Next: mcpo/README.md →](../mcpo/README.md)
## values.yaml

```yaml
proxy_config:
  model_list:
    - model_name: gpt-4.1
      litellm_params:
        model: azure/gpt-4.1
        api_base: "https://peter-8888-resource.cognitiveservices.azure.com/"
        api_key: ""
        api_version: "2024-12-01-preview"

ingress:
  enabled: true
  hosts:
    - host: litellm.onto.one
      paths:
        - path: /
          pathType: Prefix
  tls:
    - hosts:
        - litellm.onto.one
      secretName: wildcard-onto-one

extraEnv:
  - name: LITELLM_MASTER_KEY
    value: ""
  - name: UI_USERNAME
    value: ""
  - name: UI_PASSWORD
    value: ""
```