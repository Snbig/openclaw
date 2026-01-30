FROM node:22-bookworm

# Install Bun (required for build scripts)
RUN curl -fsSL https://bun.sh/install | bash
ENV PATH="/root/.bun/bin:${PATH}"

RUN corepack enable

WORKDIR /app

ARG OPENCLAW_DOCKER_APT_PACKAGES=""
RUN if [ -n "$OPENCLAW_DOCKER_APT_PACKAGES" ]; then \
      apt-get update && \
      DEBIAN_FRONTEND=noninteractive apt-get install -y --no-install-recommends $OPENCLAW_DOCKER_APT_PACKAGES && \
      apt-get clean && \
      rm -rf /var/lib/apt/lists/* /var/cache/apt/archives/*; \
    fi

COPY package.json pnpm-lock.yaml pnpm-workspace.yaml .npmrc ./
COPY ui/package.json ./ui/package.json
COPY patches ./patches
COPY scripts ./scripts

RUN pnpm install --frozen-lockfile

COPY . .
RUN OPENCLAW_A2UI_SKIP_MISSING=1 pnpm build
# Force pnpm for UI build
ENV OPENCLAW_PREFER_PNPM=1
RUN pnpm ui:install
RUN pnpm ui:build

ENV NODE_ENV=production

# --- FIX 1: DATA PERMISSIONS ---
# Your render.yaml sets OPENCLAW_STATE_DIR to /data/.openclaw.
# Since we are switching to USER node, we must create this directory 
# and give the 'node' user permission to write to it.
RUN mkdir -p /data && chown -R node:node /data

# Security hardening: Run as non-root user
USER node

# --- FIX 2: START THE GATEWAY ---
# Use shell form (no brackets) so $PORT is expanded correctly.
# This runs the specific 'gateway' command instead of just the help menu.
CMD node dist/index.js gateway --port $PORT
