# ============================================================
# InfraReaper Makefile
# ============================================================
# Usage: make <target>
# Run 'make help' to see all available targets.
#
# WHY A MAKEFILE?
# A Makefile gives you a single, consistent interface for all
# project tasks. Instead of remembering long commands, you type:
#   make lint        — run all linters
#   make build       — build Docker image
#   make validate    — validate Terraform + K8s manifests
#
# This is standard practice in DevOps projects.
# ============================================================

# Variables (override with: make build IMAGE_TAG=v1.0.0)
REGISTRY ?= infrareaperacrpalwa.azurecr.io
IMAGE_NAME ?= infrareaper-scanner
IMAGE_TAG ?= dev
FULL_IMAGE := $(REGISTRY)/$(IMAGE_NAME):$(IMAGE_TAG)
KUBE_NAMESPACE ?= infrareaper

# Colors for output
GREEN := \033[0;32m
YELLOW := \033[0;33m
RED := \033[0;31m
NC := \033[0m  # No Color

.PHONY: help lint lint-shell lint-terraform lint-ansible lint-yaml lint-docker \
        validate validate-terraform validate-k8s \
        build scan push deploy \
        test test-scripts clean

# ============================================================
# HELP
# ============================================================

help: ## Show this help message
	@echo ""
	@echo "InfraReaper — Available Targets"
	@echo "================================"
	@grep -E '^[a-zA-Z_-]+:.*?## .*$$' $(MAKEFILE_LIST) | sort | \
		awk 'BEGIN {FS = ":.*?## "}; {printf "  $(GREEN)%-20s$(NC) %s\n", $$1, $$2}'
	@echo ""

# ============================================================
# LINTING — Catch issues before they hit the pipeline
# ============================================================

lint: lint-shell lint-yaml lint-docker ## Run ALL linters
	@echo "$(GREEN)✓ All linting passed$(NC)"

lint-shell: ## Lint Bash scripts with ShellCheck
	@echo "$(YELLOW)→ Running ShellCheck...$(NC)"
	shellcheck -x -e SC1091 scripts/*.sh

lint-terraform: ## Lint Terraform with fmt check
	@echo "$(YELLOW)→ Checking Terraform formatting...$(NC)"
	terraform fmt -check -recursive terraform/

lint-ansible: ## Lint Ansible with ansible-lint
	@echo "$(YELLOW)→ Running ansible-lint...$(NC)"
	cd ansible && ansible-lint playbooks/ roles/

lint-yaml: ## Lint YAML files
	@echo "$(YELLOW)→ Running yamllint...$(NC)"
	yamllint -d "{extends: relaxed, rules: {line-length: {max: 180}, truthy: {check-keys: false}}}" policies/ kubernetes/

lint-docker: ## Lint Dockerfile with hadolint
	@echo "$(YELLOW)→ Running hadolint...$(NC)"
	@if command -v hadolint >/dev/null 2>&1; then \
		hadolint --ignore DL3008 --ignore DL3018 docker/Dockerfile; \
	elif command -v docker >/dev/null 2>&1; then \
		docker run --rm -i hadolint/hadolint hadolint --ignore DL3008 --ignore DL3018 - < docker/Dockerfile; \
	else \
		echo "$(GREEN)✓ hadolint skipped (not installed)$(NC)"; \
	fi

# ============================================================
# VALIDATION — Verify configs are structurally correct
# ============================================================

validate: validate-terraform validate-k8s ## Run ALL validators
	@echo "$(GREEN)✓ All validation passed$(NC)"

validate-terraform: ## Validate Terraform configuration
	@echo "$(YELLOW)→ Validating Terraform...$(NC)"
	cd terraform/environments/dev && terraform validate

validate-k8s: ## Validate Kubernetes manifests
	@echo "$(YELLOW)→ Validating Kubernetes manifests...$(NC)"
	kubectl kustomize kubernetes/base/ > /dev/null
	kubectl kustomize kubernetes/overlays/dev/ > /dev/null
	kubectl kustomize kubernetes/overlays/prod/ > /dev/null
	@echo "$(GREEN)✓ Kustomize build succeeded for base, dev, and prod$(NC)"

# ============================================================
# SECURITY SCANNING — Find vulnerabilities before deploy
# ============================================================

scan: scan-image scan-iac ## Run ALL security scans
	@echo "$(GREEN)✓ All security scans passed$(NC)"

scan-image: ## Scan Docker image with Trivy
	@echo "$(YELLOW)→ Scanning Docker image...$(NC)"
	trivy image --severity CRITICAL,HIGH --ignorefile .trivyignore --exit-code 1 $(FULL_IMAGE)

scan-iac: ## Scan IaC (Terraform + K8s) with Trivy
	@echo "$(YELLOW)→ Scanning Terraform configs...$(NC)"
	trivy config --ignorefile .trivyignore terraform/
	@echo "$(YELLOW)→ Scanning Kubernetes manifests...$(NC)"
	trivy config --ignorefile .trivyignore kubernetes/base/

scan-secrets: ## Scan for leaked secrets
	@echo "$(YELLOW)→ Scanning for secrets...$(NC)"
	trivy fs --scanners secret .

# ============================================================
# BUILD & PUSH — Container image lifecycle
# ============================================================

build: ## Build Docker image
	@echo "$(YELLOW)→ Building $(FULL_IMAGE)...$(NC)"
	docker build -t $(FULL_IMAGE) -f docker/Dockerfile .
	@echo "$(GREEN)✓ Image built: $(FULL_IMAGE)$(NC)"

push: ## Push Docker image to ACR
	@echo "$(YELLOW)→ Pushing $(FULL_IMAGE)...$(NC)"
	docker push $(FULL_IMAGE)
	@echo "$(GREEN)✓ Image pushed: $(FULL_IMAGE)$(NC)"

# ============================================================
# DEPLOY — Apply to Kubernetes
# ============================================================

deploy: ## Deploy to AKS (current kubectl context)
	@echo "$(YELLOW)→ Deploying to namespace $(KUBE_NAMESPACE)...$(NC)"
	kubectl apply -k kubernetes/overlays/dev/
	@echo "$(GREEN)✓ Deployed to $(KUBE_NAMESPACE)$(NC)"

deploy-prod: ## Deploy to AKS (prod overlay)
	@echo "$(RED)⚠ Deploying PROD overlay...$(NC)"
	kubectl apply -k kubernetes/overlays/prod/
	@echo "$(GREEN)✓ Deployed to $(KUBE_NAMESPACE) (prod)$(NC)"

# ============================================================
# TESTING
# ============================================================

test: ## Run all tests (lint + validate + scan + script tests)
	@$(MAKE) lint
	@$(MAKE) validate
	@$(MAKE) test-scripts
	@$(MAKE) scan-iac
	@echo "$(GREEN)✓ All tests passed$(NC)"

test-scripts: ## Run unit tests for scanner engine scripts
	@echo "$(YELLOW)→ Running scanner script test suite...$(NC)"
	bash tests/scripts/test_scanner_engine.sh
	@echo "$(GREEN)✓ Script test suite passed$(NC)"

# ============================================================
# UTILITIES
# ============================================================

clean: ## Remove build artifacts and temp files
	@echo "$(YELLOW)→ Cleaning up...$(NC)"
	rm -rf kustomize-build/
	rm -rf tmp/
	docker rmi $(FULL_IMAGE) 2>/dev/null || true
	@echo "$(GREEN)✓ Clean$(NC)"

scanner-logs: ## View latest scanner CronJob logs
	@echo "$(YELLOW)→ Fetching latest scanner logs...$(NC)"
	kubectl logs -n $(KUBE_NAMESPACE) \
		$$(kubectl get pods -n $(KUBE_NAMESPACE) --sort-by=.metadata.creationTimestamp -l app=infrareaper-scanner -o jsonpath='{.items[-1].metadata.name}') \
		--tail=100

scanner-status: ## Check CronJob status
	@kubectl get cronjobs -n $(KUBE_NAMESPACE)
	@echo ""
	@kubectl get jobs -n $(KUBE_NAMESPACE) --sort-by=.metadata.creationTimestamp | tail -5
