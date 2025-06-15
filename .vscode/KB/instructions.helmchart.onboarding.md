# Helm Chart Onboarding: Evidence-Governed Staged Checks  
_Source: OEG DevOps Ontologies, LinkML Python Library_

---

## Scripted, Dot-Pattern, Stage-Based Onboarding

**All scripts must be located in `.vscode/instruments/` and named according to the pattern:**

- `.vscode/instruments/check.remote-repo.exists.sh`
- `.vscode/instruments/check.chart-name.exists.sh`
- `.vscode/instruments/check.chart-version.available.sh`
- `.vscode/instruments/check.provider-required.sh`
- `.vscode/instruments/check.env.variables-present.sh`
- `.vscode/instruments/check.tls-cert.present.sh`
- `.vscode/instruments/check.hostname.set.sh`
- `.vscode/instruments/check.ingress.enabled.sh`
- `.vscode/instruments/check.storage.local-path.sh`
- `.vscode/instruments/check.ingress-nginx.ready.sh`

_Naming and directory structure is required for uniform automation and evidence provenance._

---

### Stage 1. Chart Location and Identity  
- `.vscode/instruments/check.remote-repo.exists.sh`  
    _Check: Remote Helm repository specified (OEG: SoftwareComponent [repo metadata])_  
- `.vscode/instruments/check.chart-name.exists.sh`  
    _Check: Chart name present in repo (OEG: SoftwareComponent [component id])_  
- `.vscode/instruments/check.chart-version.available.sh`  
    _Check: Chart version available in specified repo (OEG: SoftwareComponent version)_

---

### Stage 2. Provider and Environment  
- `.vscode/instruments/check.provider-required.sh`  
    _Check: Provider (azure, openai, openai-custom-endpoint) selected (OEG: Deployment.parameters; LinkML: Slot, enum)_  
- `.vscode/instruments/check.env.variables-present.sh`  
    _Check: All provider-required environment variables present (LinkML: Slot [required/enum])_

---

### Stage 3. Prerequisites (TLS, Ingress, Hostname, Storage)  
- `.vscode/instruments/check.tls-cert.present.sh`  
    _Check: TLS cert exists for namespace (OEG: InfrastructureResource)_  
- `.vscode/instruments/check.hostname.set.sh`  
    _Check: Hostname set/formatted for Ingress (OEG: Service, hostname)_  
- `.vscode/instruments/check.ingress.enabled.sh`  
    _Check: Ingress is enabled in chart (OEG: Service/Ingress)_  
- `.vscode/instruments/check.storage.local-path.sh`  
    _Check: Storage is via local-path StorageClass (OEG: InfrastructureResource w/storage requirement)_

---

### Stage 4. Platform/Addon  
- `.vscode/instruments/check.ingress-nginx.ready.sh`  
    _Check: ingress-nginx Helm chart is deployed and available (OEG: InfrastructureResource/PlatformComponent)_

---

## Evidence Chain

- [OEG DevOps Ontology: SoftwareComponent, Deployment, Service, InfrastructureResource](https://w3id.org/devops-infra-ont)
- [LinkML Python library docs/spec: Class, Slot, Validation](https://linkml.io/linkml-model/docs/)
- [Kubernetes StorageClass doc (for local-path):](https://kubernetes.io/docs/concepts/storage/storage-classes/)

---

## Example Checklist (Dot Pattern):

```
1. chart
  1.1 check.remote-repo.exists
  1.2 check.chart-name.exists
  1.3 check.chart-version.available
2. provider
  2.1 check.provider-required
  2.2 check.env.variables-present
3. prerequisites
  3.1 check.tls-cert.present
  3.2 check.hostname.set
  3.3 check.ingress.enabled
  3.4 check.storage.local-path
4. platform
  4.1 check.ingress-nginx.ready
```

_All scripts/checks must be implemented as individual `.sh` scripts in `.vscode/instruments/`, follow the dot-pattern, and tie back to official OEG or LinkML referenceable entities._