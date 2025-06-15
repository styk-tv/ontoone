# Project Name and Namespace Convention in start_chart-based App Deployment

## Overview

All project applications launched by `k8s/start_chart.sh` (example: `litellm`, `agentzero`, `swiss`, etc.) use a strict convention where the **first parameter** to the script (referred to as `PROJECT_NAME`) serves as:

- The project *logical name* (e.g., `"agentzero"`, `"litellm"`)
- The **Kubernetes namespace** for all related resources
- The **primary folder name** for manifests, values, and Helmfile YAMLs (i.e., `./litellm/`, `./agentzero/`)
- The base for **ingress name** and for forming hostnames (e.g., `<project_name>.onto.one`)
- All scripting, monitoring, and event reporting operations

## Canonical Usage

```sh
bash ./k8s/start_chart.sh agentzero oci://... [other args...]
```

In the script:
- `PROJECT_NAME="$1"`
- `NAMESPACE="$PROJECT_NAME"` (derived; always set from the same variable)
- All `kubectl` and Helmfile commands use `-n $NAMESPACE`
- All monitoring, tailing, pod selector, and uninstall logic are namespaced strictly via this variable.

### Resource References

- **Helmfile/values:**  
  `./$PROJECT_NAME/helmfile.yaml.gotmpl`
- **Namespace:**  
  `kubectl -n $NAMESPACE ...`
- **Ingress:**  
  `name: $PROJECT_NAME` (and, commonly, DNS: `$PROJECT_NAME.onto.one`)
- **Pod selection and lifecycle monitoring:**  
  Always in `$NAMESPACE`, selector derived from `$PROJECT_NAME`.

## Why this matters

- **Predictability and Simplicity:** Always knowing that the first parameter configures the *entire environment* (namespace, manifests, selectors, ingress, tailing) avoids mismatches and orphaned resources.
- **Automation:** Tools, scripts, and CI jobs can safely reference the same parameter for all cluster and configuration operations.
- **Multi-tenancy:** Parallel environments never conflict, each cluster tenant is "sandboxed" under their own namespace and resource paths.

## Recap

**If you change the `PROJECT_NAME` or `$1`,**  
you change:

- The namespace where everything is deployed, tailed, and monitored
- All resource logical names and folder prefixes

**Always derive all paths, namespaces, and Helmfile references from the single, top-level `$PROJECT_NAME` parameter for reliability.**