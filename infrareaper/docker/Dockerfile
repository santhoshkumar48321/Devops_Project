# ============================================================
# InfraReaper Container Image Definition
# ============================================================
# Hardened container runtime for executing InfraReaper cloud
# governance and lifecycle sweeps on AKS. Compliant with CIS
# Docker benchmarks and non-root execution.
# Base OS: Microsoft Azure Linux 3.0 (CBL-Mariner).
# ============================================================

FROM mcr.microsoft.com/azure-cli:2.64.0-azurelinux3.0

# OCI Standard Image Annotations
LABEL org.opencontainers.image.title="InfraReaper Scanner" \
      org.opencontainers.image.description="Automated Azure Cloud Resource Lifecycle & Cost Governance Engine" \
      org.opencontainers.image.version="1.0.0" \
      org.opencontainers.image.vendor="InfraReaper Team" \
      org.opencontainers.image.licenses="Apache-2.0"

# Use bash with pipefail for shell execution safety
SHELL ["/bin/bash", "-o", "pipefail", "-c"]

# Install runtime utilities:
# - shadow-utils: provides useradd/groupadd for user isolation
# - curl & jq: for API interactions (SendGrid, Pushgateway, JSON parsing)
# - ca-certificates: TLS verification for Azure ARM and SendGrid
RUN tdnf install -y \
        shadow-utils \
        curl \
        jq \
        ca-certificates && \
    tdnf clean all

# Create unprivileged system user and group (UID 10001) for least-privilege security
RUN groupadd -g 10001 infrareaper && \
    useradd -u 10001 -g infrareaper -m -s /bin/bash infrareaper && \
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
