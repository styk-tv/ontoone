# cyber-k8s-monitor.py

This script provides a stylized, cyberpunk-themed terminal UI for monitoring Kubernetes cluster status using Python's curses library.

## Purpose

- Dynamically displays Kubernetes cluster status in the terminal.
- Intercepts and parses output from an external monitoring script (e.g., colima-k8s-persistent.sh).
- Presents real-time updates with character-by-character typing effects and adaptive layout.

## Features

- Robust terminal UI with Python's curses library.
- Distinct sections for Colima status, Kube info, pods, etc.
- Cyberpunk-themed colors, ASCII borders, and blinking indicators.
- Supports terminal resizing and graceful shutdown.

## Usage

1. Ensure Python 3 is installed.
2. Make the script executable: `chmod +x cyber-k8s-monitor.py`
3. Update your VSCode tasks.json to run this script.
4. Ensure `SOURCE_SCRIPT_PATH` points to your Kubernetes monitoring script.
5. Run the script via Task Manager or directly.

- To exit: Press `q` or Ctrl+C.

## Parameters

- **SOURCE_SCRIPT_PATH**: Path to the external script providing Kubernetes status output (set in the script).
---

**Breadcrumb:** [Home (../README.md)](../README.md) > [TASKS](../TASKS.md) > [PROJECTS](../PROJECTS.md) > Scripts > cyber-k8s-monitor.py

[← Previous: cyber-k8s-logstream.py.md](cyber-k8s-logstream.py.md) | [Next: ../README.md →](../README.md)