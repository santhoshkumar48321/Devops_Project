# Ansible Automation Test Suite

This directory contains testing specifications and integration test definitions for InfraReaper's Ansible configuration roles.

## 🧪 Testing Scope

The Ansible roles (`azdo-agent`, `common`, `docker`, `security`) are validated using:
- **Ansible Lint**: Syntax, best practices, and idempotency checks (`ansible-lint`).
- **Dry-Run Check Mode**: Executed in CI/CD via `ansible-playbook --check --diff`.
- **Molecule Test Framework**: Isolated container testing to assert state convergence on Ubuntu 24.04 LTS images.

## 🚀 Running Tests Locally

```bash
# 1. Run Ansible Lint
ansible-lint infrareaper/ansible/playbooks/setup-lab-server.yml

# 2. Syntax Check
ansible-playbook --syntax-check -i infrareaper/ansible/inventory/hosts.yml infrareaper/ansible/playbooks/setup-lab-server.yml
```

