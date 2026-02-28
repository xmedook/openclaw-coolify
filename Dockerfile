# syntax=docker/dockerfile:1

########################################
# Stage 1: Base System
########################################
FROM node:20-bookworm-slim AS base

ENV DEBIAN_FRONTEND=noninteractive \
    PIP_ROOT_USER_ACTION=ignore

RUN apt-get update && apt-get install -y --no-install-recommends \
    curl wget git unzip build-essential python3 python3-pip python3-venv \
    jq lsof openssl ca-certificates gnupg ripgrep fd-find fzf bat \
    pandoc poppler-utils ffmpeg imagemagick graphviz sqlite3 pass chromium \
    && rm -rf /var/lib/apt/lists/*

ENV PYTHON=/usr/bin/python3 \
    npm_config_python=/usr/bin/python3
RUN ln -sf /usr/bin/python3 /usr/bin/python && npm install -g node-gyp

########################################
# Stage 2: Runtimes
########################################
FROM base AS runtimes
ENV BUN_INSTALL="/data/.bun" \
    PATH="/usr/local/go/bin:/data/.bun/bin:/data/.bun/install/global/bin:$PATH"
RUN curl -fsSL https://bun.sh/install | bash
RUN pip3 install ipython csvkit openpyxl python-docx pypdf botasaurus browser-use playwright --break-system-packages && \
    playwright install-deps

########################################
# Stage 3: Dependencies
########################################
FROM runtimes AS dependencies
ARG OPENCLAW_BETA=false
ENV OPENCLAW_BETA=${OPENCLAW_BETA} \
    OPENCLAW_NO_ONBOARD=1 \
    NPM_CONFIG_UNSAFE_PERM=true

# Instalación de Docker CLI oficial (API 1.44)
RUN install -m 0755 -d /etc/apt/keyrings && \
    curl -fsSL https://download.docker.com/linux/debian/gpg | gpg --dearmor -o /etc/apt/keyrings/docker.gpg && \
    chmod a+r /etc/apt/keyrings/docker.gpg && \
    echo "deb [arch=$(dpkg --print-architecture) signed-by=/etc/apt/keyrings/docker.gpg] https://download.docker.com/linux/debian $(. /etc/os-release && echo "$VERSION_CODENAME") stable" | \
    tee /etc/apt/sources.list.d/docker.list > /dev/null && \
    apt-get update && apt-get install -y docker-ce-cli && \
    rm -rf /var/lib/apt/lists/*

COPY --from=ghcr.io/astral-sh/uv:latest /uv /uvx /bin/

# INSTALACIÓN LOCAL EN /app PARA EVITAR PERDER EL BINARIO
WORKDIR /app
RUN npm install openclaw

########################################
# Stage 4: Final
########################################
FROM dependencies AS final
WORKDIR /app
COPY . .

# CREACIÓN DE LINKS MANUALES (FORZADOS)
RUN ln -sf /app/node_modules/.bin/openclaw /usr/local/bin/openclaw && \
    ln -sf /app/node_modules/.bin/openclaw-approve /usr/local/bin/openclaw-approve && \
    ln -sf /app/node_modules/.bin/openclaw-onboard /usr/local/bin/openclaw-onboard && \
    chmod +x /app/scripts/*.sh

# VARIABLES DE ENTORNO
ENV DOCKER_HOST="unix:///var/run/docker.sock"
ENV DOCKER_API_VERSION="1.44"
# Agregamos /app/node_modules/.bin al principio del PATH
ENV PATH="/app/node_modules/.bin:/usr/local/bin:/usr/bin:/bin:${PATH}"

EXPOSE 18789

# El truco final: si exec openclaw falla en el script, lo llamamos por su ruta absoluta
CMD ["bash", "-c", "cp /app/node_modules/.bin/openclaw /usr/bin/openclaw || true; bash /app/scripts/bootstrap.sh"]
