# MCPO Project

This folder contains the Helm chart and configuration for the MCPO deployment.

## Tasks

| Task Label         | How to Launch | Command / Script | Description |
|--------------------|---------------|------------------|-------------|
| 33 mcpo.onto.one   | Task Manager  | sh ./k8s/start_chart.sh mcpo | Launches the MCPO Helm chart into Kubernetes |

## Configuration Files

- **helm/values.yaml**  
  Main configuration file for the MCPO Helm chart. Edit this file to set deployment parameters, environment variables, and other options for your MCPO instance.

- **helm/Chart.yaml**  
  Helm chart metadata for MCPO.

## Usage

1. Use the Task Manager extension in VSCode to launch the "33 mcpo.onto.one" task to deploy MCPO.
---

**Breadcrumb:** [Home (../README.md)](../README.md) > [TASKS](../TASKS.md) > [PROJECTS](../PROJECTS.md) > mcpo

[← Previous: litellm/README.md](../litellm/README.md) | [Next: milvus/README.md →](../milvus/README.md)