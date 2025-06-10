# Swiss Project

This folder contains the Helm chart and configuration for the Swiss deployment.

## Tasks

| Task Label         | How to Launch | Command / Script | Description |
|--------------------|---------------|------------------|-------------|
| 91 swiss.onto.one  | Task Manager  | (see tasks.json) | Launches the Swiss Helm chart into Kubernetes |

## Configuration Files

- **values.yaml**  
  Main configuration file for the Swiss Helm chart. Edit this file to set deployment parameters, environment variables, and other options for your Swiss instance.

- **helm/Chart.yaml**  
  Helm chart metadata for Swiss.

## Usage

1. Use the Task Manager extension in VSCode to launch the "91 swiss.onto.one" task to deploy Swiss.
## values.yaml

```yaml
replicaCount: 1
image:
  repository: leodotcloud/swiss-army-knife
  tag: latest
  pullPolicy: IfNotPresent
resources:
  limits:
    cpu: "1"
    memory: "512Mi"
  requests:
    cpu: "0.5"
    memory: "256Mi"
env: []
ingress:
  enabled: true
  hosts:
    - host: swiss.onto.one
  tls:
    - secretName: wildcard-onto-one
```
---

**Breadcrumb:** [Home (../README.md)](../README.md) > [TASKS](../TASKS.md) > [PROJECTS](../PROJECTS.md) > swiss

[← Previous: openwebui/README.md](../openwebui/README.md) | [Next: ../k8s/install-wildcard.sh.md →](../k8s/install-wildcard.sh.md)