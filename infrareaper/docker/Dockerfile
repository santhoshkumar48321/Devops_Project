# ============================================================
# InfraReaper Container Image Definition
# ============================================================
# Hardened container runtime for executing InfraReaper cloud
# governance and lifecycle sweeps on AKS. Compliant with CIS
# Docker benchmarks and non-root execution.
# Base: Microsoft Azure CLI official runtime.
# ============================================================

ARG AZ_CLI_VERSION=latest
FROM mcr.microsoft.com/azure-cli:${AZ_CLI_VERSION}

# OCI Standard Image Annotations
LABEL org.opencontainers.image.title="InfraReaper Scanner" \
      org.opencontainers.image.description="Automated Azure Cloud Resource Lifecycle & Cost Governance Engine" \
      org.opencontainers.image.version="1.0.0" \
      org.opencontainers.image.vendor="InfraReaper Team" \
      org.opencontainers.image.licenses="Apache-2.0"

# Use bash with pipefail for shell execution safety
SHELL ["/bin/bash", "-o", "pipefail", "-c"]

# Universal package installation and OS updates (supports Azure Linux tdnf, Debian apt, and Alpine apk)
# hadolint ignore=DL3008,DL3018
RUN if command -v tdnf >/dev/null 2>&1; then \
        tdnf upgrade -y && \
        tdnf install -y shadow-utils curl jq ca-certificates && \
        tdnf clean all; \
    elif command -v apt-get >/dev/null 2>&1; then \
        apt-get update && \
        apt-get upgrade -y && \
        apt-get install -y --no-install-recommends curl jq ca-certificates && \
        rm -rf /var/lib/apt/lists/*; \
    elif command -v apk >/dev/null 2>&1; then \
        apk update && apk upgrade && \
        apk add --no-cache bash curl jq ca-certificates coreutils; \
    fi

# Create unprivileged system user and group (UID 10001) for least-privilege security
RUN if command -v groupadd >/dev/null 2>&1; then \
        groupadd -g 10001 infrareaper && \
        useradd -u 10001 -g infrareaper -m -s /bin/bash infrareaper; \
    else \
        addgroup -g 10001 -S infrareaper && \
        adduser -u 10001 -S -G infrareaper -h /home/infrareaper -s /bin/bash infrareaper; \
    fi && \
    mkdir -p /home/infrareaper/.azure /tmp/infrareaper /app && \
    chown -R 10001:10001 /home/infrareaper /tmp/infrareaper /app

# Set working directory
WORKDIR /app

# Copy application policies and scripts into container
COPY --chown=10001:10001 policies/ /app/policies/
COPY --chown=10001:10001 scripts/ /app/scripts/

# Ensure scripts have execute permissions
RUN chmod +x /app/scripts/*.sh

# Run as unprivileged user
USER 10001:10001

# Environment configurations
ENV HOME="/home/infrareaper" \
    AZURE_CONFIG_DIR="/home/infrareaper/.azure" \
    OUTPUT_DIR="/tmp/infrareaper" \
    PATH="/app/scripts:${PATH}"

# Define entrypoint to run the master orchestrator
ENTRYPOINT ["/app/scripts/main.sh"]
