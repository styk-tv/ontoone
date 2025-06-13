#!/bin/bash
# Creates a wildcard TLS secret in multiple namespaces using the certificate
# and key from the k8s folder. Works similarly to the original script, but can
# take namespaces as arguments or default to "default" if none are provided.

# Use absolute paths so we can run this script from anywhere:
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
CERT_FILE="${SCRIPT_DIR}/_wildcard.onto.one+1.pem"
KEY_FILE="${SCRIPT_DIR}/_wildcard.onto.one+1-key.pem"

# Default secret name
SECRET_NAME="wildcard-onto-one"

# Collect passed namespaces or default to 'default'
if [ $# -eq 0 ]; then
  NAMESPACES=("default")
else
  NAMESPACES=("$@")
fi

# Check certificate/key existence
if [ ! -f "${CERT_FILE}" ] || [ ! -f "${KEY_FILE}" ]; then
  echo "Certificate or key file not found."
  echo "Make sure ${CERT_FILE} and ${KEY_FILE} exist in k8s folder."
  exit 1
fi

echo "Installing TLS secret '${SECRET_NAME}' using:"
echo " - cert : ${CERT_FILE}"
echo " - key  : ${KEY_FILE}"
echo
echo "Target namespaces: ${NAMESPACES[@]}"

for ns in "${NAMESPACES[@]}"; do
  echo "Ensuring namespace '$ns' exists..."
  kubectl create namespace "$ns" 2>/dev/null || true

  echo "Applying TLS secret '${SECRET_NAME}' in namespace '$ns'..."
  kubectl create secret tls "${SECRET_NAME}" \
    --cert="${CERT_FILE}" \
    --key="${KEY_FILE}" \
    --dry-run=client -o yaml | kubectl apply -n "$ns" -f -
  echo "Wildcard certificate secret '${SECRET_NAME}' created/updated in namespace '$ns'."
  echo
done

echo "Certificate secret installation complete!"