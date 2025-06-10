# install-wildcard.sh

This script creates a wildcard TLS secret in one or more Kubernetes namespaces using the wildcard certificate and key from the `k8s` folder.

## Purpose

- Automates the creation of a TLS secret (`wildcard-onto-one`) in specified namespaces.
- Uses the certificate (`_wildcard.onto.one+1.pem`) and key (`_wildcard.onto.one+1-key.pem`) files.

## Usage

```sh
./install-wildcard.sh [namespace1 namespace2 ...]
```

- If no namespaces are provided, defaults to `default`.
- Can be run from any directory.

## Parameters

- **Namespaces**: List of Kubernetes namespaces to install the secret into. If omitted, uses `default`.

## What it does

1. Checks for the existence of the certificate and key files in the `k8s` folder.
2. For each namespace:
   - Ensures the namespace exists (creates it if needed).
   - Creates a TLS secret named `wildcard-onto-one` using the provided certificate and key.
---

**Breadcrumb:** [Home (../README.md)](../README.md) > [TASKS](../TASKS.md) > [PROJECTS](../PROJECTS.md) > Scripts > install-wildcard.sh

[← Previous: ../swiss/README.md](../swiss/README.md) | [Next: start_chart.sh.md →](start_chart.sh.md)