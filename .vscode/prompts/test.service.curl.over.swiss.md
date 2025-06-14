# Service-to-Service Connectivity (DNS Shortcut): Curl to Litellm Service from Swiss Pod

## 1. Trigger

A user gives a command such as:
> curl to litellm service over swiss

## 2. Parse and Operationalize

Understand that this means:
- From inside a running pod in the `swiss` namespace (the source),
- Test HTTP connectivity directly to the litellm service using Kubernetes service DNS (not FQDN), which resolves as:
  ```
  http://<service-name>.<namespace>:<port>
  ```
  So for litellm: `http://litellm.litellm:4000`

## 3. Ordered Operations (Service Name DNS Form)

```sh
# Find a suitable pod name in swiss namespace
kubectl get pods -n swiss
# Use the first running pod found, e.g.:
# NAME                     READY   STATUS    RESTARTS   AGE
# swiss-766c7c7756-8m94t   1/1     Running   0          72m

# Exec into the swiss pod
kubectl exec -it -n swiss swiss-766c7c7756-8m94t -- /bin/sh

# Within the swiss pod, test connectivity via short service DNS
curl -v http://litellm.litellm:4000
```

## 4. Verification

A successful HTTP response means swiss can reach the litellm service via the Kubernetes internal DNS shortcut.

---

## 5. Generic Script (Variable-based, Dynamic Pod Lookup)

```sh
# Set your variables for source and destination
SRC_NS="swiss"
DST_NS="litellm"
DST_SVC="litellm"
DST_PORT="4000"

# Lookup the first running pod in the source namespace to handle GUID in pod name
SRC_POD=$(kubectl get pods -n "$SRC_NS" -o jsonpath='{.items[?(@.status.phase=="Running")].metadata.name}' | awk '{print $1}')

# Exec into the pod and curl the target using service name DNS (protocol://svc.ns:port)
kubectl exec -it -n "$SRC_NS" "$SRC_POD" -- /bin/sh -c \
  "curl -v http://$DST_SVC.$DST_NS:$DST_PORT"
```

*This approach works for any internal service within the cluster and uses the standard service name plus namespace within the URL for rapid, DNS-based connectivity testing.*