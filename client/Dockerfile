# =============================================================================
# CLIENT DOCKERFILE — React Frontend served by Nginx
# =============================================================================
# Stage 1: Build React app into static files using Vite
# Stage 2: Serve with Nginx (lightweight, fast, production-grade)
#
# Nginx proxies /api/* requests to the backend container.
# =============================================================================

# --- Stage 1: Build ---
FROM node:20-alpine AS builder

WORKDIR /app

COPY package*.json ./
RUN npm ci

COPY . .
RUN npm run build

# --- Stage 2: Serve with Nginx ---
FROM nginx:alpine

# Remove default nginx page
RUN rm -rf /usr/share/nginx/html/*

# Copy built React files
COPY --from=builder /app/dist /usr/share/nginx/html

# Custom nginx config for SPA routing + API proxy
COPY nginx.conf /etc/nginx/conf.d/default.conf

# Non-root user (nginx alpine already runs worker as nginx user)
RUN chown -R nginx:nginx /usr/share/nginx/html && \
    chown -R nginx:nginx /var/cache/nginx && \
    chown -R nginx:nginx /var/log/nginx && \
    touch /var/run/nginx.pid && \
    chown -R nginx:nginx /var/run/nginx.pid

EXPOSE 80

HEALTHCHECK --interval=30s --timeout=5s --start-period=10s --retries=3 \
  CMD wget --no-verbose --tries=1 --spider http://localhost:80/ || exit 1

CMD ["nginx", "-g", "daemon off;"]
