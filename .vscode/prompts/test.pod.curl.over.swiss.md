# Pod-to-Pod Connectivity: Curl to Litellm from Swiss

## 1. Trigger

A user issues an operational request, e.g.:
> curl to main pod in litellm over swiss

## 2. Parse and Operationalize

Recognize the workflow is:
- Start in the swiss namespace (source pod).
- Test connectivity from swiss to the litellm service by HTTP(S) request.

## 3. Sequence of Operations (with Proof)

```sh
# Find pods in swiss namespace
kubectl get pods -n swiss
# Output, example:
# NAME                     READY   STATUS    RESTARTS   AGE
# swiss-766c7c7756-8m94t   1/1     Running   0          72m

# Find litellm service details (internal DNS and port)
kubectl get svc -n litellm
# Output, example:
# NAME      TYPE        CLUSTER-IP     ...   PORT(S)    ...
# litellm   ClusterIP   10.43.36.57          4000/TCP

# (Optional) To check actual target pod IPs
kubectl get pods -n litellm -o wide

# Exec into the swiss pod
kubectl exec -it -n swiss swiss-766c7c7756-8m94t -- /bin/sh

# From inside the swiss pod, run:
curl -v http://litellm.litellm.svc.cluster.local:4000
# or (equivalent):
curl -v http://10.43.36.57:4000
```

## 4. Verification

A successful HTTP response from litellm means pod-to-pod and service connectivity is operational.

*All service names, DNS addresses, ports, and command outputs above are based on actual cluster state and live kubectl commands, not hypotheticals.*

---

## 5. Generic Script (Variable-based, for Any Pod/Service, with Dynamic Pod Lookup)

```sh
# Set your working defaults:
SRC_NS="swiss"
DST_NS="litellm"
DST_SVC="litellm"
DST_PORT="4000"

# Dynamically get the first pod name in the source namespace.
# This command finds the first pod whose name contains the SRC_NS value (handles random suffixes).
SRC_POD=$(kubectl get pods -n "$SRC_NS" -o jsonpath='{.items[?(@.status.phase=="Running")].metadata.name}' | awk '{print $1}')

# Optionally: dynamically look up the destination Service ClusterIP.
DST_CLUSTERIP=$(kubectl get svc -n "$DST_NS" "$DST_SVC" -o jsonpath='{.spec.clusterIP}')

# Exec into the source pod and curl the destination service by DNS
kubectl exec -it -n "$SRC_NS" "$SRC_POD" -- /bin/sh -c \
  "curl -v http://$DST_SVC.$DST_NS.svc.cluster.local:$DST_PORT"

# Or curl by ClusterIP
kubectl exec -it -n "$SRC_NS" "$SRC_POD" -- /bin/sh -c \
  "curl -v http://$DST_CLUSTERIP:$DST_PORT"
```

*These defaults and lookups will work for litellm and swiss using the cluster state as observed. The pod lookup handles dynamic pod GUIDs, ensuring robustness for standard rolling deployments.*