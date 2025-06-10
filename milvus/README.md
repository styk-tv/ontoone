# Milvus Project

This folder contains the Helm chart and configuration for the Milvus vector database deployment.

## Tasks

| Task Label              | How to Launch | Command / Script | Description |
|-------------------------|---------------|------------------|-------------|
| 21 milvus.onto.one      | Task Manager  | sh ./k8s/start_chart.sh milvus https://zilliztech.github.io/milvus-helm/ milvus 4.1.15 | Launches the Milvus Helm chart into Kubernetes |
| 22 milvus.onto.one EXEC | Task Manager  | kubectl exec -it -n milvus -- /bin/sh | Opens a shell directly into the Milvus pod |

## Configuration Files

- **values.yaml**  
  Main configuration file for the Milvus Helm chart. Edit this file to set deployment parameters, environment variables, and other options for your Milvus instance.

- **original-values.yaml**  
  Reference file containing the original/default values for the Helm chart. Use this as a guide to see all possible configuration options available for Milvus.

## Usage

1. Use the Task Manager extension in VSCode to launch the "21 milvus.onto.one" task to deploy Milvus.
2. Use the "22 milvus.onto.one EXEC" task to open a shell in the running Milvus pod for troubleshooting or direct interaction.
## values.yaml

```yaml
nameOverride: ""
fullnameOverride: ""
cluster:
  enabled: false
image:
  all:
    repository: milvusdb/milvus
    tag: v2.5.12
    pullPolicy: IfNotPresent
  tools:
    repository: milvusdb/milvus-config-tool
    tag: v0.1.2
    pullPolicy: IfNotPresent
extraEnv: []
proxy:
  enabled: true
  replicas: 1
  extraEnv: []
ingress:
  enabled: true
  annotations:
    nginx.ingress.kubernetes.io/backend-protocol: GRPC
    nginx.ingress.kubernetes.io/ssl-redirect: "true"
  hosts:
    - host: milvus.onto.one
      path: "/"
      pathType: Prefix
  tls:
    - secretName: wildcard-onto-one
      hosts:
        - milvus.onto.one
```
---

**Breadcrumb:** [Home (../README.md)](../README.md) > [TASKS](../TASKS.md) > [PROJECTS](../PROJECTS.md) > milvus

[← Previous: mcpo/README.md](../mcpo/README.md) | [Next: openwebui/README.md →](../openwebui/README.md)