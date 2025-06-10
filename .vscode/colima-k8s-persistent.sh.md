# colima-k8s-persistent.sh

This script sets up a persistent Colima Kubernetes environment with Klipper LoadBalancer and shared storage mapping.

## Purpose

- Starts Colima in Kubernetes mode with persistent storage mapped from the host.
- Ensures kubeconfig is properly set up for kubectl access.
- Handles graceful shutdown and cleanup on termination signals.
- Logs output to `/tmp/colima-k8s-persistent.log`.

## Usage

```sh
./colima-k8s-persistent.sh
```

## Parameters

- **HOST_COMPOSE_PATH**: Path on the host for shared storage (edit in script if needed).
- **VM_COMPOSE_PATH**: Path inside the Colima VM for shared storage.

## What it does

1. Moves any existing log file to a backup.
2. Sets up signal handlers for graceful shutdown.
3. Ensures kubeconfig is configured for Colima.
4. Starts Colima with Kubernetes and persistent storage.
5. Handles shutdown and cleanup when stopped.
---

**Breadcrumb:** [Home (../README.md)](../README.md) > [TASKS](../TASKS.md) > [PROJECTS](../PROJECTS.md) > Scripts > colima-k8s-persistent.sh

[← Previous: ../k8s/start_chart.sh.md](../k8s/start_chart.sh.md) | [Next: cyber-k8s-logstream.py.md →](cyber-k8s-logstream.py.md)