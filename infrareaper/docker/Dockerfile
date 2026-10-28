# ============================================================
# InfraReaper Container Image Definition
# ============================================================
# Hardened container runtime for executing InfraReaper cloud
# governance and lifecycle sweeps on AKS. Compliant with CIS
# Docker benchmarks and non-root execution.
# ============================================================

FROM mcr.microsoft.com/azure-cli:2.64.0-alpine

# OCI Standard Image Annotations
LABEL org.opencontainers.image.title="InfraReaper Scanner" \
      org.opencontainers.image.description="Automated Azure Cloud Resource Lifecycle & Cost Governance Engine" \
      org.opencontainers.image.version="1.0.0" \
      org.opencontainers.image.vendor="InfraReaper Team" \
      org.opencontainers.image.licenses="Apache-2.0"

# Use bash with pipefail for shell safety
SHELL ["/bin/bash", "-o", "pipefail", "-c"]

# Install runtime utilities: jq for JSON, curl for API calls, coreutils for GNU date
RUN apk update && \
    apk add --no-cache \
        bash \
        curl \
        jq \
        coreutils \
        ca-certificates && \
    rm -rf /var/cache/apk/*

# Create unprivileged system user and group (UID 10001) for least-privilege security
RUN addgroup -g 10001 -S infrareaper && \
    adduser -u 10001 -S -G infrareaper -h /home/infrareaper -s /bin/bash infrareaper && \
    mkdir -p /home/infrareaper/.azure /tmp/infrareaper /app && \
    chown -R 10001:10001 /home/infrareaper /tmp/infrareaper /app

# Set working directory
WORKDIR /app

# Copy application assets into container
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
