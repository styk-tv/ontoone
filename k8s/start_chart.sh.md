# start_chart.sh

This script manages the lifecycle of a Helm chart, supporting both local and remote chart deployments. It handles installation, upgrade, and graceful shutdown.

## Purpose

- Automates deployment of Helm charts for project services.
- Supports both local charts (in the project folder) and remote charts (from a Helm repository).

## Usage

### Local Chart Deployment

```sh
./start_chart.sh <project_name>
```
- Example: `./start_chart.sh agentzero`
- Assumes the chart is in `./<project_name>/helm/` and values in `./<project_name>/values.yaml`.

### Remote Chart Deployment

```sh
./start_chart.sh <project_name> <helm_repo_url> <helm_chart_name> <helm_chart_version>
```
- Example: `./start_chart.sh my-app https://charts.bitnami.com/bitnami nginx-ingress 1.2.3`
- Deploys a chart from the specified Helm repository, using project-level values.yaml if present.

## Parameters

- **project_name**: Name of the project (required).
- **helm_repo_url**: URL of the Helm repository (remote mode only).
- **helm_chart_name**: Name of the Helm chart (remote mode only).
- **helm_chart_version**: Version of the Helm chart (remote mode only).

## What it does

- Determines deployment mode (local or remote) based on arguments.
- Installs or upgrades the Helm chart for the specified project.
- Applies values from the project's values.yaml if available.
- Handles graceful shutdown on termination signals.
---

**Breadcrumb:** [Home (../README.md)](../README.md) > [TASKS](../TASKS.md) > [PROJECTS](../PROJECTS.md) > Scripts > start_chart.sh

[← Previous: install-wildcard.sh.md](install-wildcard.sh.md) | [Next: ../.vscode/colima-k8s-persistent.sh.md →](../.vscode/colima-k8s-persistent.sh.md)