# syntax=docker/dockerfile:1

########################################
# Stage 1: Base System (ACTUALIZADO A NODE 22)
########################################
FROM node:22-bookworm-slim AS base
ENV DEBIAN_FRONTEND=noninteractive
RUN apt-get update && apt-get install -y --no-install-recommends \
    curl wget git unzip build-essential python3 python3-pip python3-venv \
    jq lsof openssl ca-certificates gnupg ripgrep fd-find fzf bat \
    pandoc poppler-utils ffmpeg imagemagick graphviz sqlite3 pass chromium \
    && rm -rf /var/lib/apt/lists/*

########################################
# Stage 2: Runtimes & Docker CLI
########################################
FROM base AS runtimes
RUN install -m 0755 -d /etc/apt/keyrings && \
    curl -fsSL https://download.docker.com/linux/debian/gpg | gpg --dearmor -o /etc/apt/keyrings/docker.gpg && \
    chmod a+r /etc/apt/keyrings/docker.gpg && \
    echo "deb [arch=$(dpkg --print-architecture) signed-by=/etc/apt/keyrings/docker.gpg] https://download.docker.com/linux/debian $(. /etc/os-release && echo "$VERSION_CODENAME") stable" | \
    tee /etc/apt/sources.list.d/docker.list > /dev/null && \
    apt-get update && apt-get install -y docker-ce-cli && \
    rm -rf /var/lib/apt/lists/*

ENV BUN_INSTALL="/root/.bun"
ENV PATH="/root/.bun/bin:$PATH"
RUN curl -fsSL https://bun.sh/install | bash

########################################
# Stage 3: Final Setup
########################################
FROM runtimes AS final
WORKDIR /app
COPY . .

# Instalamos OpenClaw usando BUN
RUN bun install -g openclaw

# Fix de permisos para /data
RUN mkdir -p /data && chmod -R 777 /data

# Enlaces simbólicos
RUN ln -sf /root/.bun/bin/openclaw /usr/local/bin/openclaw && \
    ln -sf /root/.bun/bin/openclaw-approve /usr/local/bin/openclaw-approve && \
    chmod +x /app/scripts/*.sh

# Variables de entorno
ENV DOCKER_HOST="unix:///var/run/docker.sock"
ENV DOCKER_API_VERSION="1.44"
ENV OPENCLAW_DATA_DIR="/data"
ENV PATH="/root/.bun/bin:/usr/local/bin:/usr/bin:/bin:${PATH}"

EXPOSE 18789

# Comando de arranque
CMD ["bash", "-c", "chmod -R 777 /data || true; bash /app/scripts/bootstrap.sh"]
