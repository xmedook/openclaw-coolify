# syntax=docker/dockerfile:1

########################################
# Stage 1: Base System
########################################
FROM node:20-bookworm-slim AS base

ENV DEBIAN_FRONTEND=noninteractive \
    PIP_ROOT_USER_ACTION=ignore

# Core packages + build tools
RUN apt-get update && apt-get install -y --no-install-recommends \
    curl \
    wget \
    git \
    unzip \
    build-essential \
    python3 \
    python3-pip \
    python3-venv \
    jq \
    lsof \
    openssl \
    ca-certificates \
    gnupg \
    ripgrep fd-find fzf bat \
    pandoc \
    poppler-utils \
    ffmpeg \
    imagemagick \
    graphviz \
    sqlite3 \
    pass \
    chromium \
    && rm -rf /var/lib/apt/lists/*

# 🔥 CRITICAL FIX (native modules)
ENV PYTHON=/usr/bin/python3 \
    npm_config_python=/usr/bin/python3

RUN ln -sf /usr/bin/python3 /usr/bin/python && \
    npm install -g node-gyp

########################################
# Stage 2: Runtimes
########################################
FROM base AS runtimes

ENV BUN_INSTALL="/data/.bun" \
    PATH="/usr/local/go/bin:/data/.bun/bin:/data/.bun/install/global/bin:$PATH"

# Install Bun
RUN curl -fsSL https://bun.sh/install | bash

# Python tools
RUN pip3 install ipython csvkit openpyxl python-docx pypdf botasaurus browser-use playwright --break-system-packages && \
    playwright install-deps

ENV XDG_CACHE_HOME="/data/.cache"

########################################
# Stage 3: Dependencies
########################################
FROM runtimes AS dependencies

ARG OPENCLAW_BETA=false
ENV OPENCLAW_BETA=${OPENCLAW_BETA} \
    OPENCLAW_NO_ONBOARD=1 \
    NPM_CONFIG_UNSAFE_PERM=true

# 🛠️ INSTALACIÓN DE DOCKER OFICIAL (Para API 1.44)
RUN install -m 0755 -d /etc/apt/keyrings && \
    curl -fsSL https://download.docker.com/linux/debian/gpg | gpg --dearmor -o /etc/apt/keyrings/docker.gpg && \
    chmod a+r /etc/apt/keyrings/docker.gpg && \
    echo "deb [arch=$(dpkg --print-architecture) signed-by=/etc/apt/keyrings/docker.gpg] https://download.docker.com/linux/debian $(. /etc/os-release && echo "$VERSION_CODENAME") stable" | \
    tee /etc/apt/sources.list.d/docker.list > /dev/null && \
    apt-get update && apt-get install -y docker-ce-cli && \
    rm -rf /var/lib/apt/lists/*

# 🛠️ INSTALACIÓN DE UV
COPY --from=ghcr.io/astral-sh/uv:latest /uv /uvx /bin/

# Instalar OpenClaw Globalmente
RUN --mount=type=cache,target=/data/.npm \
    if [ "$OPENCLAW_BETA" = "true" ]; then \
    npm install -g openclaw@beta; \
    else \
    npm install -g openclaw; \
    fi 

# 🛠️ SYM-LINK UV PARA CLAUDE/KIMI
RUN ln -sf /usr/local/bin/uv /usr/local/bin/claude || true && \
    ln -sf /usr/local/bin/uv /usr/local/bin/kimi || true

########################################
# Stage 4: Final
########################################
FROM dependencies AS final

WORKDIR /app
COPY . .

# 🛠️ SOLUCIÓN MAESTRA PARA "OPENCLAW NOT FOUND"
# Buscamos el binario donde sea que npm lo haya escondido y lo ponemos en el PATH global
RUN OPENCLAW_PATH=$(find /usr/local/lib/node_modules/openclaw -name openclaw -type f -executable | head -n 1) || \
    OPENCLAW_PATH=$(which openclaw) && \
    if [ -n "$OPENCLAW_PATH" ]; then \
        ln -sf "$OPENCLAW_PATH" /usr/local/bin/openclaw; \
        ln -sf "$(dirname $OPENCLAW_PATH)/openclaw-approve" /usr/local/bin/openclaw-approve || true; \
    fi && \
    chmod +x /app/scripts/*.sh

# Variables de entorno críticas para Docker y Binarios
ENV DOCKER_HOST="unix:///var/run/docker.sock"
ENV DOCKER_API_VERSION="1.44"
ENV PATH="/usr/local/bin:/usr/local/lib/node_modules/openclaw/bin:/root/.local/bin:/data/.bun/bin:${PATH}"

EXPOSE 18789

# Comando de arranque con auto-reparación de PATH
CMD ["bash", "-c", "ln -sf $(which openclaw) /usr/local/bin/openclaw || true; bash /app/scripts/bootstrap.sh"]
