# MASTER BOT KNOWLEDGE BASE (KB)

> **Optimized for AI LLM BOT traversal and logic mapping**
>
> All knowledge below is encapsulated from `.vscode/prompts/`, structurally and semantically linked for advanced traversal, chaining, and automation.

---

## 📒 Index

1. [Project Name & Namespace Convention](#project-name--namespace-convention)
   - [Definition](#definition)
   - [Canonical Usage](#canonical-usage)
   - [Relationships & Mappings](#relationships--mappings)
   - [Resource Reference Map](#resource-reference-map)
   - [Rationale](#rationale)
   - [Recap](#recap)
   - [Traversal & Reasoning Notes](#traversal--reasoning-notes)
2. [Testing Strategies](#testing-strategies)
   - [Pod-to-Pod Connectivity Test](#pod-to-pod-connectivity-test)
   - [Service-to-Service Connectivity Test (DNS Shortcut)](#service-to-service-connectivity-test-dns-shortcut)
   - [Ingress Connectivity Test (HTTPS)](#ingress-connectivity-test-https)
   - [TRIPLE Curl Sequence (Mandatory Order)](#triple-curl-connectivity-test-sequence)
   - [Dependencies & Semantic Links](#test-requirements--dependencies)

---

## Project Name & Namespace Convention

(See detailed breakdown in [`Project Name & Namespace Convention`](#project-name--namespace-convention). This section forms the base for service, ingress, and DNS referencing in all tests.)

...

### [See full contents: already in previous version, unchanged, as per `.vscode/prompts/explained.project_name.and.namespace.md`]

---

## <a name="testing-strategies"></a>Testing Strategies

Collection of deterministic, automatable connectivity tests between Kubernetes namespaces, services, and externally exposed ingresses. Each test sequence (and the [TRIPLE Curl](#triple-curl-connectivity-test-sequence)) is mandatory for validating different network layers.

### <a name="pod-to-pod-connectivity-test"></a>Pod-to-Pod Connectivity Test

- **Purpose:** Ensure direct pod-level and service-level HTTP(S) reachability between source `swiss` pod and destination `litellm` pod/service.
- **Canonical Trigger:**  
  User command: `curl to main pod in litellm over swiss`
- **Procedure:**
  1. Find a running pod in `swiss`:
     ```
     kubectl get pods -n swiss
     ```
  2. Get `litellm` service info:
     ```
     kubectl get svc -n litellm
     ```
  3. Exec into swiss pod and run:
     ```
     curl -v http://litellm.litellm.svc.cluster.local:4000
     # or
     curl -v http://<ClusterIP>:4000
     ```
  4. Successful HTTP response = pod/service network and service mesh is working.

- **Automation Script:**
  See [Pod-to-Pod Connectivity Section](#pod-to-pod-connectivity-test) or `.vscode/prompts/test.pod.curl.over.swiss.md`.

---

### <a name="service-to-service-connectivity-test-dns-shortcut"></a>Service-to-Service Connectivity Test (DNS Shortcut)

- **Purpose:** Validate Kubernetes internal DNS routing (`service.namespace`) for network reachability.
- **Canonical Trigger:**  
  User command: `curl to litellm service over swiss`
- **Procedure:**
  - Exec into a swiss pod and run:
    ```
    curl -v http://litellm.litellm:4000
    ```
  - If HTTP response received, internal routing and DNS mapping are operational.

- **Generic Automation:**
  See `.vscode/prompts/test.service.curl.over.swiss.md`.

---

### <a name="ingress-connectivity-test-https"></a>Ingress Connectivity Test (HTTPS)

- **Purpose:** Validate that services are externally reachable via ingress gateway (typically via HTTPS with SNI/TLS).
- **Canonical Trigger:**  
  User command: `test ingress from swiss`
- **Procedure:**
  1. Find a swiss pod, exec in:
     ```
     kubectl exec -it -n swiss <pod-name> -- /bin/sh
     ```
  2. Inside the pod, execute:
     ```
     curl -vk --resolve <HOSTNAME>:443:<GATEWAY_IP> https://<HOSTNAME>
     # Example:
     curl -vk --resolve litellm.onto.one:443:192.168.5.2 https://litellm.onto.one
     ```
  3. **Must set** GATEWAY_IP to gateway IP (e.g., Colima IP) and HOSTNAME see [Project Name & Namespace Convention](#project-name--namespace-convention).

- **Generic Dynamic Automation:**
  ```
  SRC_NS="swiss"
  SRC_POD=$(kubectl get pods -n "$SRC_NS" -o jsonpath='{.items[?(@.status.phase=="Running")].metadata.name}' | awk '{print $1}')
  GATEWAY_IP="..."
  HOSTNAME="..."
  kubectl exec -it -n "$SRC_NS" "$SRC_POD" -- /bin/sh -c \
    "curl -vk --resolve $HOSTNAME:443:$GATEWAY_IP https://$HOSTNAME"
  ```
  See `.vscode/prompts/test.ingress.curl.over.swiss.md` for authoritative detail.

---

### <a name="triple-curl-connectivity-test-sequence"></a>TRIPLE Curl Connectivity Test Sequence

- **Purpose:** Enforce strict order of pod → service → ingress validation; abort sequence if any step fails.
- **Mandatory Sequence:**
  1. [Pod Connectivity Test](#pod-to-pod-connectivity-test)
  2. [Service Connectivity Test](#service-to-service-connectivity-test-dns-shortcut)
  3. [Ingress Connectivity Test](#ingress-connectivity-test-https)
  - If any stage does not produce expected HTTP(S) response, abort and report failure.

- **Canonical trigger:**  
  The triple-curl validation orchestrates all other connectivity checks.
- **Automation Snippet:**
  ```
  # 1. Pod-level test (DNS + ClusterIP)
  # 2. Service-level test
  # 3. Ingress-level test (with --resolve)
  ```
  **If any check fails, abort and return failure stage. If all pass, network path is operational.**

  See `.vscode/prompts/test.tripple.curl.md` for full sequential automation.

---

### <a name="test-requirements--dependencies"></a>Test Requirements & Dependencies

- All **Testing Strategies** require strict adherence to [Project Name & Namespace Convention](#project-name--namespace-convention):
  - Namespace in all commands is always set based on `PROJECT_NAME`.
  - Service names, DNS, and ingress hostnames are resolved via the `$PROJECT_NAME` linkage.
- Each test builds on successful completion of the previous:
  - Triple Curl → 1. Pod test → 2. Service test → 3. Ingress test.
- If automating, use [dynamic pod lookup, namespace logic, and substitution variables] described in each corresponding section.
- Use the *relationship* and *mappings* provided for error diagnosis, precondition verification, and per-stage automation.

---

## Traversal & Reasoning Notes (AI/LLM Optimization Section)

- Traverse first to the [Index](#index) to identify which protocol/route/test is being requested or triggered (pod, service, ingress, sequence).
- For any test scenario, determine:
  - The source and destination namespaces/services (`swiss`, `litellm`, etc.), referencing naming conventions.
  - The operation layer (direct pod, k8s DNS, ingress).
  - The required shell/kubectl sequence, with correct variables interpolated from the conventions.
- Whenever orchestrating automation:
  - Use the triple-curl sequence for comprehensive checks
  - Reference canonical scripts for robust, error-tolerant dynamic lookup
  - Always validate that prerequisite steps succeeded before proceeding to the next test
- **Violation Detection:**  
  If any script or config is not derived from `PROJECT_NAME` or breaks the namespace/service mapping logic, flag for convention violation.

---

### [END KB]  
*This KB is the single reference for resource conventions and test automation strategies used across kubernetes deployments with agentzero, litellm, swiss, etc. Update upon prompt additions.*