# Ingress Connectivity Test: Curl to Ingress Endpoint from Swiss Pod (via HTTPS)

## 1. Trigger

A user issues a command like:
> test ingress from swiss

## 2. Parse and Operationalize

- The goal is to verify connectivity from a pod in the `swiss` namespace to an ingress endpoint exposed by the main gateway (e.g., Colima), over HTTPS.
- The test is performed using `curl` with:
  - The `--insecure` flag (to allow self-signed SSL)
  - The ingress controller's exposed IP address as the URL target (usually the Colima gateway IP).
  - The `-H "Host: ..." ` header set to the desired hostname (as used in the ingress definition).

## 3. Sequence of Operations

```sh
# 1. Find a running pod in swiss namespace
kubectl get pods -n swiss
# Example:
# NAME                     READY   STATUS    RESTARTS   AGE
# swiss-766c7c7756-8m94t   1/1     Running   0          72m

# 2. Exec into the swiss pod
kubectl exec -it -n swiss swiss-766c7c7756-8m94t -- /bin/sh

# 3. From within the swiss pod, perform HTTPS curl to ingress/gateway. 
# Replace <GATEWAY_IP> with the external IP or gateway IP for Colima, 
# and <HOSTNAME> with the ingress virtual host.
curl -vk --resolve <HOSTNAME>:443:<GATEWAY_IP> https://<HOSTNAME>
# Example:
# curl -vk --resolve litellm.onto.one:443:192.168.5.2 https://litellm.onto.one
```

## 4. Generic Script (Variable-based, Dynamic Pod Lookup)

```sh
SRC_NS="swiss"
SRC_POD=$(kubectl get pods -n "$SRC_NS" -o jsonpath='{.items[?(@.status.phase=="Running")].metadata.name}' | awk '{print $1}')
GATEWAY_IP="192.168.5.2"    # Replace with actual Colima gateway IP
HOSTNAME="litellm.onto.one" # Set to the required ingress host

kubectl exec -it -n "$SRC_NS" "$SRC_POD" -- /bin/sh -c \
  "curl -vk --resolve $HOSTNAME:443:$GATEWAY_IP https://$HOSTNAME"
```

## 5. Verification

A successful connection and valid HTTP response proves that traffic from swiss pod to ingress via the Colima gateway and correct hostname is operational.

*Ensure GATEWAY_IP and HOSTNAME reflect your real environment and ingress configuration for an accurate test.*