# OpenWebUI Project

This folder contains the Helm chart and configuration for the OpenWebUI deployment.

## Tasks

| Task Label                | How to Launch | Command / Script | Description |
|---------------------------|---------------|------------------|-------------|
| 31 openwebui.onto.one     | Task Manager  | sh ./k8s/start_chart.sh openwebui https://helm.openwebui.com open-webui 6.19.0 | Launches the OpenWebUI Helm chart into Kubernetes |
| 32 openwebui.onto.one EXEC| Task Manager  | kubectl exec -it ... -n openwebui -- /bin/bash | Opens a shell directly into the OpenWebUI pod |

## Configuration Files

- **values.yaml**  
  Main configuration file for the OpenWebUI Helm chart. Edit this file to set deployment parameters, environment variables, and other options for your OpenWebUI instance.

## Usage

1. Use the Task Manager extension in VSCode to launch the "31 openwebui.onto.one" task to deploy OpenWebUI.
2. Use the "32 openwebui.onto.one EXEC" task to open a shell in the running OpenWebUI pod for troubleshooting or direct interaction.
## values.yaml

```yaml
ingress:
  enabled: true
  class: ""
  host: openwebui.onto.one
  tls: true
  existingSecret: wildcard-onto-one

websocket:
  enabled: true
  manager: redis
  url: redis://open-webui-redis:6379/0

extraEnvVars:
  - name: OPENAI_API_KEY
    value: "sk-openai-api-key"
  - name: OPENAI_API_BASE_URLS
    value: "http://litellm.litellm:4000"
  - name: DEFAULT_MODELS
    value: "gpt-4.1"
  - name: MILVUS_URI
    value: "http://milvus.milvus:19530"
  - name: MILVUS_TOKEN
    value: ""
  - name: MILVUS_DB
    value: "default"
  - name: VECTOR_DB
    value: "milvus"
```
---

**Breadcrumb:** [Home (../README.md)](../README.md) > [TASKS](../TASKS.md) > [PROJECTS](../PROJECTS.md) > openwebui

[← Previous: milvus/README.md](../milvus/README.md) | [Next: swiss/README.md →](../swiss/README.md)