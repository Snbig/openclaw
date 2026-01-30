FROM node:22-bookworm

# 1. Install Bun
RUN curl -fsSL https://bun.sh/install | bash
ENV PATH="/root/.bun/bin:${PATH}"

# 2. Enable pnpm
RUN corepack enable

WORKDIR /app

# 3. Install system deps
ARG OPENCLAW_DOCKER_APT_PACKAGES=""
RUN if [ -n "$OPENCLAW_DOCKER_APT_PACKAGES" ]; then \
      apt-get update && \
      DEBIAN_FRONTEND=noninteractive apt-get install -y --no-install-recommends $OPENCLAW_DOCKER_APT_PACKAGES && \
      apt-get clean && \
      rm -rf /var/lib/apt/lists/* /var/cache/apt/archives/*; \
    fi

# 4. Copy dependency files
COPY package.json pnpm-lock.yaml pnpm-workspace.yaml .npmrc ./
COPY ui/package.json ./ui/package.json
COPY patches ./patches
COPY scripts ./scripts

# 5. Install dependencies
RUN pnpm install --frozen-lockfile

# 6. Copy source
COPY . .

# 7. Build backend
RUN OPENCLAW_A2UI_SKIP_MISSING=1 pnpm build

# 8. Build UI
ENV OPENCLAW_PREFER_PNPM=1
RUN pnpm ui:install
RUN pnpm ui:build

ENV NODE_ENV=production

# 9. Run as non-root user
USER node

# 10. CRITICAL FIXES:
# - max-old-space-size=384: Prevents crashing on Render Free Tier (512MB limit)
# - allow-unconfigured: Prevents crashing because /tmp config is missing
# - gateway --port $PORT: Starts the server so Render health checks pass
CMD node --max-old-space-size=384 dist/index.js gateway --port $PORT --allow-unconfigured
