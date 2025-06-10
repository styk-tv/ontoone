# Cyber K8s Launcher

This project enables rapid experimentation with self-hosted projects on your laptop, using a disposable Kubernetes environment mapped to your workstation. All services are accessible via valid SSL certificates and fully qualified domain names (FQDNs), but everything still points to `127.0.0.1` for local development.

- **First button:** Starts Colima Kubernetes (Task 01).
- **Other buttons:** Instantly deploy Helm charts for your chosen projects. When you stop a task, the Helm chart is uninstalled and resources are freed.
- **Persistence:** All work is stored on your workstation, so data is preserved between sessions.
- **Resilience:** The system is designed for eventual consistency and can recover from interruptions or shutdowns. For critical data, use backups, but for day-to-day playground use, this is ideal.

> _"Sharing this with the world as a rapid, resilient playground for self-hosted experimentation."_  
> — Peter

---

## Mini Task Table

| Task Label                  | What it Does                                      |
|-----------------------------|---------------------------------------------------|
| 01 COLIMA [KUBERNETES]      | Starts Colima in Kubernetes mode                  |
| 03 CYBER K8S MONITOR        | Monitors Colima and Kubernetes logs               |
| 11 litellm.onto.one         | Deploys Litellm Helm chart                        |
| 21 milvus.onto.one          | Deploys Milvus Helm chart                         |
| 31 openwebui.onto.one       | Deploys OpenWebUI Helm chart                      |
| 33 mcpo.onto.one            | Deploys MCPO Helm chart                           |
| 91 swiss.onto.one           | Deploys Swiss Helm chart                          |

_Use the VSCode Task Manager extension to launch these tasks. EXEC tasks (shell access) are available but not listed here._

---

## 1. Prerequisites

- **macOS** (tested on Apple Silicon and Intel)
- [Colima](https://github.com/abiosoft/colima) (container runtime for macOS)
- [mkcert](https://github.com/FiloSottile/mkcert) (for local SSL certificates)
- [Visual Studio Code](https://code.visualstudio.com/)
  - Extension: **Task Manager** (`cnshenj.vscode-task-manager`)

---

## 2. Colima Setup

Colima supports two modes:
- **Container mode** (default, like Docker Desktop)
- **Kubernetes mode** (used in this project)

**We use Kubernetes mode.**

### Install Colima

```sh
brew install colima
```

---

## 3. Folder Mapping & Data Persistence

To ensure all pod/container data is stored on your workstation (and not inside Colima or containers):

- Map a folder from your workstation to Colima.
- Map from Colima to each container/pod.

**Result:**  
Pods write output directly to your workstation disk.  
You can destroy Colima, stop all pods, erase and reinstall everything, and your data will persist as long as it stays in the mapped location.

---

## 4. VSCode Integration & Helper Files

- Helper scripts and configuration files are in the `.vscode` folder.
- The main set of tasks is in `.vscode/tasks.json`.
- **Required VSCode extension:**  
  [Task Manager](https://marketplace.visualstudio.com/items?itemName=cnshenj.vscode-task-manager) (`cnshenj.vscode-task-manager`)

---

## 5. Networking, Load Balancer & Certificates

- Load balancer is configured to expose services on low ports.
- SSL certificates are generated for a seamless browsing experience (no need to remember port numbers).
- You can access services by name (e.g., `milvus.onto.one`) instead of port numbers.

---

## 6. Domain: onto.one

- The domain `onto.one` (registered by PeterS) always points to `localhost`.
- This allows you to create subdomains for each service (e.g., `milvus.onto.one`).
- The wildcard `*.onto.one` points to `127.0.0.1` for local development.
- No need to modify your local DNS system.

**Example:**  
Creating a new service called `milvus` will:
- Create a project and namespace `milvus`
- Expose it at `milvus.onto.one`
- Wildcard DNS ensures it resolves to your local machine

**If you prefer, you can manually add entries to your `/etc/hosts` file.**

---

**Breadcrumb:** Home (README.md)

[Next: TASKS.md →](TASKS.md)