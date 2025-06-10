# Helm Chart Projects

This workspace contains the following Helm chart projects. Each project is a folder with a Helm chart and related configuration.

| Project   | Path         | Helm Chart Location         | values.yaml Location                | Description |
|-----------|--------------|----------------------------|-------------------------------------|-------------|
| litellm   | litellm/     | litellm/helm/              | litellm/values.yaml                 | Litellm deployment |
| mcpo      | mcpo/        | mcpo/helm/                 | mcpo/helm/values.yaml               | MCPO deployment |
| milvus    | milvus/      | milvus/helm/               | milvus/values.yaml                  | Milvus vector database |
| openwebui | openwebui/   | openwebui/helm-original/   | openwebui/values.yaml               | OpenWebUI interface |
| swiss     | swiss/       | swiss/helm/                | swiss/values.yaml                   | Swiss project |

**Notes:**
- Some projects have `values-original.yaml` or `original-values.yaml` files, which are reference files showing all possible Helm values.
- Each project folder should contain a README.md describing its tasks and configuration.
---

**Breadcrumb:** [Home (README.md)](README.md) > [TASKS](TASKS.md) > PROJECTS

[← Previous: TASKS.md](TASKS.md) | [Next: litellm/README.md →](litellm/README.md)