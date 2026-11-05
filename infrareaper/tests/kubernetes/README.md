# Kubernetes Manifests & Policy Test Suite

This directory contains validation and compliance testing specifications for InfraReaper's Kubernetes workloads and monitoring resources.

## 🧪 Testing Scope

- **Kustomize Validation**: Asserts that `base`, `overlays/dev`, `overlays/prod`, and `monitoring` build without syntax or schema errors.
- **Trivy Configuration Scan**: Scans all Kubernetes manifests against CIS Kubernetes benchmarks to prevent privilege escalation and enforce Pod Security Standards.
- **NetworkPolicy Validation**: Validates that zero-ingress policies block unauthorized external network connections.

## 🚀 Running Tests Locally

```bash
# 1. Validate Kustomize Build for all targets
kubectl kustomize infrareaper/kubernetes/base > /dev/null
kubectl kustomize infrareaper/kubernetes/overlays/dev > /dev/null
kubectl kustomize infrareaper/kubernetes/overlays/prod > /dev/null
kubectl kustomize infrareaper/kubernetes/monitoring > /dev/null

# 2. Run Trivy Config Scan
trivy config infrareaper/kubernetes/
```
