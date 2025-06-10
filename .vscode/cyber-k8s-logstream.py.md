# cyber-k8s-logstream.py

This script streams and colorizes log output, using ANSI colors and ASCII art for enhanced readability. It is designed to process and display logs from Kubernetes or related processes.

## Purpose

- Streams log files or command output.
- Colorizes and highlights log sections using various ANSI color codes.
- Uses ASCII art for section headers and visual emphasis.

## Usage

```sh
python3 cyber-k8s-logstream.py [options] <logfile>
```

- `<logfile>`: Path to the log file to stream and colorize.

## Features

- Supports multiple color themes for log output.
- Recognizes section headers and highlights them.
- Uses the `art` Python package for ASCII banners.
- Can be extended to process different log formats.

## Parameters

- **logfile**: Path to the log file to stream (required).
- Additional options may be available; see script source for details.
---

**Breadcrumb:** [Home (../README.md)](../README.md) > [TASKS](../TASKS.md) > [PROJECTS](../PROJECTS.md) > Scripts > cyber-k8s-logstream.py

[← Previous: colima-k8s-persistent.sh.md](colima-k8s-persistent.sh.md) | [Next: cyber-k8s-monitor.py.md →](cyber-k8s-monitor.py.md)