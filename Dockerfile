# MI-SOAR-NGFW Base Image
# Debian-based container with common security tools and dependencies

FROM debian:bookworm-slim AS base

LABEL maintainer="MI-SOAR-NGFW Team"
LABEL description="Base Debian image for MI-SOAR-NGFW platform"
LABEL version="1.0.0"

# Install security updates and common dependencies
RUN apt-get update && apt-get upgrade -y --no-install-recommends && \
    apt-get install -y --no-install-recommends \
    # Essential tools
    ca-certificates \
    curl \
    wget \
    gnupg \
    lsb-release \
    # Security & networking
    net-tools \
    iproute2 \
    iptables \
    nftables \
    tcpdump \
    # Monitoring
    procps \
    htop \
    # Debugging
    less \
    vim-tiny \
    # Python for scripts
    python3 \
    python3-pip \
    # Clean up
    && rm -rf /var/lib/apt/lists/*

# Set Python3 as default
RUN ln -sf /usr/bin/python3 /usr/bin/python

# Create non-root user for security
RUN groupadd -r -g 1000 appuser && \
    useradd -r -u 1000 -g appuser -s /bin/bash -d /home/appuser -m appuser

# Create directories for configurations and logs
RUN mkdir -p /etc/mi-soar-ngfw /var/log/mi-soar-ngfw && \
    chown -R appuser:appuser /etc/mi-soar-ngfw /var/log/mi-soar-ngfw

# Switch to non-root user
USER appuser
WORKDIR /home/appuser

# Health check script
COPY --chown=appuser:appuser scripts/monitoring/health-check.sh /usr/local/bin/health-check.sh
RUN chmod +x /usr/local/bin/health-check.sh

HEALTHCHECK --interval=30s --timeout=10s --start-period=5s --retries=3 \
    CMD ["/usr/local/bin/health-check.sh"]

# Default command
CMD ["/bin/bash"]