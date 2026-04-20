# =============================================================================
# COMBINED DOCKERFILE — Frontend (React) + Backend (Express)
# =============================================================================
# Stage 1: Build the React frontend into static files
# Stage 2: Install backend production dependencies
# Stage 3: Final minimal image serving both frontend & API
#
# How it works:
# - React builds into static HTML/CSS/JS files
# - Express serves those files AND handles /api/* routes
# - One container, one port (3001), one ALB target group
# =============================================================================

# --- Stage 1: Build React Frontend ---
FROM node:20-alpine AS frontend-builder

WORKDIR /app/client

COPY client/package*.json ./
RUN npm ci

COPY client/ ./
RUN npm run build

# --- Stage 2: Install Backend Dependencies ---
FROM node:20-alpine AS backend-builder

WORKDIR /app/server

COPY server/package*.json ./
COPY server/prisma ./prisma/

RUN npm ci --omit=dev && npx prisma generate

# --- Stage 3: Production Image ---
FROM node:20-alpine

WORKDIR /app

# Install wget for health checks
RUN apk add --no-cache wget

# Create non-root user
RUN addgroup -g 1001 -S appgroup && \
    adduser -S appuser -u 1001 -G appgroup

# Copy backend dependencies and source
COPY --from=backend-builder /app/server/node_modules ./node_modules
COPY --from=backend-builder /app/server/node_modules/.prisma ./node_modules/.prisma
COPY server/src ./src
COPY server/prisma ./prisma
COPY server/package*.json ./

# Copy frontend build output into server's public directory
COPY --from=frontend-builder /app/client/dist ./public

# Environment variables
ENV NODE_ENV=production
ENV PORT=3001
ENV DATABASE_URL="file:./data/dev.db"

# Create data directory and set permissions
RUN mkdir -p ./data && chown -R appuser:appgroup /app

# Switch to non-root user
USER appuser

# Initialize database
RUN npx prisma db push --skip-generate 2>/dev/null || true

EXPOSE 3001

# Health check
HEALTHCHECK --interval=30s --timeout=5s --start-period=60s --retries=3 \
  CMD wget --no-verbose --tries=1 --spider http://localhost:3001/api/health || exit 1

CMD ["node", "src/index.js"]
