# Triple Curl Connectivity Test Sequence

**Instructions: This document defines a deterministic, sequenced strategy for automated connectivity testing from swiss to litellm targets. Follow all steps exactly. Do not continue if any stage fails.**

---

## 1. Pod Connectivity Test

- **Purpose:** Confirm direct pod-to-pod network reachability and HTTP readiness using cluster DNS and ClusterIP.
- **Instructions:**
  1. Find a running pod in the source namespace `swiss`:
     ```sh
     SRC_NS="swiss"
     SRC_POD=$(kubectl get pods -n "$SRC_NS" -o jsonpath='{.items[?(@.status.phase=="Running")].metadata.name}' | awk '{print $1}')
     ```
  2. Retrieve service variables for destination:
     ```sh
     DST_NS="litellm"
     DST_SVC="litellm"
     DST_PORT="4000"
     DST_CLUSTERIP=$(kubectl get svc -n "$DST_NS" "$DST_SVC" -o jsonpath='{.spec.clusterIP}')
     ```
  3. Exec into source pod and curl both service DNS and ClusterIP:
     ```sh
     kubectl exec -it -n "$SRC_NS" "$SRC_POD" -- /bin/sh -c \
       "curl -sv http://$DST_SVC.$DST_NS.svc.cluster.local:$DST_PORT && curl -sv http://$DST_CLUSTERIP:$DST_PORT"
     ```
  4. **If HTTP connection and valid response is not received, STOP. Do not proceed.**

---

## 2. Service Connectivity Test

- **Purpose:** Verify that Kubernetes internal DNS (service-name.namespace) maps correctly and ClusterIP routing is functioning.
- **Instructions:**
  1. From the same swiss pod, execute:
     ```sh
     kubectl exec -it -n "$SRC_NS" "$SRC_POD" -- /bin/sh -c \
       "curl -sv http://$DST_SVC.$DST_NS:$DST_PORT"
     ```
  2. **If HTTP connection and valid response is not received, STOP. Do not proceed.**

---

## 3. Ingress Connectivity Test

- **Purpose:** Confirm external ingress path is working, including TLS acceptance and correct virtual host.
- **Instructions:**
  1. Set the ingress gateway environment variables:
     ```sh
     GATEWAY_IP="192.168.5.2"    # Substitute with your gateway (e.g., Colima IP)
     HOSTNAME="litellm.onto.one" # Substitute with your ingress host
     ```
  2. From the same swiss pod, exec curl with SNI and --insecure flag:
     ```sh
     kubectl exec -it -n "$SRC_NS" "$SRC_POD" -- /bin/sh -c \
       "curl -vk --resolve $HOSTNAME:443:$GATEWAY_IP https://$HOSTNAME"
     ```
  3. **If HTTPS connection and valid response is not received, report ingress failure.**

---

**MANDATORY SEQUENCE:**  
- Pod connectivity check → Service connectivity check → Ingress connectivity check  
- **If any prior step fails, abort mission. Return status: failed at stage X.**  
- **If all pass, return status: all connectivity checks successful.**