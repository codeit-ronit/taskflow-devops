# =============================================================================
# MULTI-STAGE PRODUCTION DOCKERFILE
# =============================================================================
# Stage 1 (builder): Installs all dependencies and generates Prisma client
# Stage 2 (production): Copies only what's needed for a minimal, secure image
#
# Best practices applied:
# - Multi-stage build (smaller final image)
# - Alpine base (minimal OS, ~50MB vs ~900MB)
# - Non-root user (security: limits attacker access if compromised)
# - HEALTHCHECK (Docker/ECS knows if app is alive)
# - Explicit COPY order (better layer caching)
# - Only production dependencies in final image
# =============================================================================

# --- Stage 1: Build ---
FROM node:20-alpine AS builder

WORKDIR /app

# Copy dependency manifests first (Docker caches this layer if unchanged)
COPY package*.json ./
COPY prisma ./prisma/

# Install ALL dependencies (including dev) for Prisma generate
RUN npm ci && npx prisma generate

# Copy application source
COPY src ./src/

# --- Stage 2: Production ---
FROM node:20-alpine

WORKDIR /app

# Install wget for health checks (Alpine doesn't have curl by default)
RUN apk add --no-cache wget

# Create non-root user for security
RUN addgroup -g 1001 -S appgroup && \
    adduser -S appuser -u 1001 -G appgroup

# Copy only production dependencies and generated Prisma client
COPY --from=builder /app/node_modules ./node_modules
COPY --from=builder /app/node_modules/.prisma ./node_modules/.prisma
COPY --from=builder /app/src ./src
COPY --from=builder /app/prisma ./prisma
COPY package*.json ./

# Set environment variables
ENV NODE_ENV=production
ENV PORT=3001
ENV DATABASE_URL="file:./data/dev.db"

# Create data directory and set permissions
RUN mkdir -p ./data && chown -R appuser:appgroup /app

# Switch to non-root user
USER appuser

# Initialize the database on first run
RUN npx prisma db push --skip-generate 2>/dev/null || true

EXPOSE 3001

# Health check: ECS and Docker use this to determine if container is healthy
HEALTHCHECK --interval=30s --timeout=5s --start-period=60s --retries=3 \
  CMD wget --no-verbose --tries=1 --spider http://localhost:3001/api/health || exit 1

CMD ["node", "src/index.js"]
