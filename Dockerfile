# syntax=docker/dockerfile:1

########################################
# Stage 1: Base System
########################################
FROM node:20-bookworm-slim AS base
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
# Instalación de Docker CLI oficial
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

# Instalamos OpenClaw usando BUN (más fiable en las rutas)
RUN bun install -g openclaw

# Forzamos los enlaces simbólicos donde el script bootstrap espera verlos
RUN ln -sf /root/.bun/bin/openclaw /usr/local/bin/openclaw && \
    ln -sf /root/.bun/bin/openclaw-approve /usr/local/bin/openclaw-approve && \
    chmod +x /app/scripts/*.sh

# Variables de entorno críticas
ENV DOCKER_HOST="unix:///var/run/docker.sock"
ENV DOCKER_API_VERSION="1.44"
ENV PATH="/root/.bun/bin:/usr/local/bin:/usr/bin:/bin:${PATH}"

EXPOSE 18789

# El comando de arranque: Verificamos si existe el comando antes de lanzar bootstrap
CMD ["bash", "-c", "which openclaw || ln -sf /root/.bun/bin/openclaw /usr/local/bin/openclaw; bash /app/scripts/bootstrap.sh"]
