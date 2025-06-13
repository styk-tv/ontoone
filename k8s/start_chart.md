# start_chart.sh Usage and Helmfile Destruction State Machine

This guide describes the usage of `start_chart.sh` for managing litellm on your k8s cluster, as well as the destruction/teardown sequence after SIGINT or uninstall.

---

## Helmfile Destruction and Persistence Flow

Upon SIGINT (Ctrl+C) or explicit destroy, startup/shutdown monitoring and final reporting obey these requirements:
- All non-stateful resources (Deployments, Pods, Services, Ingresses, etc.) in the namespace are deleted and the script waits for them to be fully gone.
- PersistentVolumeClaims (PVCs) and ConfigMaps (CMs) may intentionally remain and should not block termination.
- After cleanup, the script displays a **final report** summarizing surviving PVCs and ConfigMaps.

### Destruction State Machine

See [k8s/helmfile_destroy_flow.md](helmfile_destroy_flow.md) for the full requirements, or view the diagram below:

![Helmfile Destruction State Machine](helmfile_destroy_flow.svg)

- The SVG diagram presents each state and transition involved in the safe teardown and reporting process.
- This documentation is updated in tandem with the destruction/cleanup logic of the main script.