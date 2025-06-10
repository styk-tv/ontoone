# Workspace Tasks

This file lists all tasks defined in `.vscode/tasks.json`, including how they are launched and their parameters.

| Label                        | Launch Method | Command / Script | Parameters / Notes |
|------------------------------|--------------|------------------|-------------------|
| 01 COLIMA [KUBERNETES] - PERSISTENT | Shell        | .vscode/colima-k8s-persistent.sh | Background task, starts Colima in Kubernetes mode |
| 02 COLIMA EXEC               | Shell        | ssh colima-k8s   | Opens shell into Colima VM |
| 03 CYBER K8S MONITOR         | Shell        | .vscode/cyber-k8s-logstream.py /tmp/colima-k8s-persistent.log | Background log monitor for Colima |
| 11 litellm.onto.one          | Shell        | ./k8s/start_chart.sh litellm oci://ghcr.io/berriai/litellm-helm litellm-helm 0.1.694 | Launches litellm Helm chart |
| 12 litellm.onto.one EXEC     | Shell        | kubectl exec -it ... -n litellm -- /bin/sh | Opens shell in litellm pod |
| 21 milvus.onto.one           | Shell        | ./k8s/start_chart.sh milvus https://zilliztech.github.io/milvus-helm/ milvus 4.1.15 | Launches milvus Helm chart |
| 22 milvus.onto.one EXEC      | Shell        | kubectl exec -it -n milvus -- /bin/sh | Opens shell in milvus pod |
| 31 openwebui.onto.one        | Shell        | ./k8s/start_chart.sh openwebui https://helm.openwebui.com open-webui 6.19.0 | Launches openwebui Helm chart |
| 32 openwebui.onto.one EXEC   | Shell        | kubectl exec -it ... -n openwebui -- /bin/bash | Opens shell in openwebui pod |
| 33 mcpo.onto.one             | Shell        | ./k8s/start_chart.sh mcpo | Launches mcpo Helm chart |
| 91 swiss.onto.one            | Shell        | (not shown in snippet) | (details in tasks.json) |

**Notes:**
- Tasks with "EXEC" in the label open a shell directly into the running pod/container.
- Tasks with a project name (e.g., litellm, milvus, openwebui, mcpo, swiss) launch the corresponding Helm chart.
- The Colima and cyber-k8s tasks are for environment setup and monitoring.

For full details and additional parameters, see `.vscode/tasks.json`.
---

**Breadcrumb:** [Home (README.md)](README.md) > TASKS

[← Previous: README.md](README.md) | [Next: PROJECTS.md →](PROJECTS.md)