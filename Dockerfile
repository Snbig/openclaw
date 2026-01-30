FROM node:22-bookworm

# 1. Install Bun (required for internal build scripts)
RUN curl -fsSL https://bun.sh/install | bash
ENV PATH="/root/.bun/bin:${PATH}"

# 2. Enable pnpm
RUN corepack enable

WORKDIR /app

# 3. Install optional system packages (if defined in build args)
ARG OPENCLAW_DOCKER_APT_PACKAGES=""
RUN if [ -n "$OPENCLAW_DOCKER_APT_PACKAGES" ]; then \
      apt-get update && \
      DEBIAN_FRONTEND=noninteractive apt-get install -y --no-install-recommends $OPENCLAW_DOCKER_APT_PACKAGES && \
      apt-get clean && \
      rm -rf /var/lib/apt/lists/* /var/cache/apt/archives/*; \
    fi

# 4. Copy dependency files first (for better Docker caching)
COPY package.json pnpm-lock.yaml pnpm-workspace.yaml .npmrc ./
COPY ui/package.json ./ui/package.json
COPY patches ./patches
COPY scripts ./scripts

# 5. Install dependencies
RUN pnpm install --frozen-lockfile

# 6. Copy source code
COPY . .

# 7. Build the backend
RUN OPENCLAW_A2UI_SKIP_MISSING=1 pnpm build

# 8. Build the UI
# We force pnpm here to avoid potential architecture issues with Bun on some cloud builds
ENV OPENCLAW_PREFER_PNPM=1
RUN pnpm ui:install
RUN pnpm ui:build

ENV NODE_ENV=production

# 9. Security: Run as non-root user
# Since you are using /tmp in your Render Env Vars, the 'node' user can write there automatically.
USER node

# 10. CRITICAL FIX: Start the Gateway
# This uses shell expansion so the $PORT variable from Render (8080) is read correctly.
CMD node dist/index.js gateway --port $PORT
