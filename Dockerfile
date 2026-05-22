# ─────────────────────────────────────────────
# Stage 1: Dependencies
# ─────────────────────────────────────────────
FROM node:18.15.0-alpine AS deps

WORKDIR /app

# Copy package files only for better layer caching
COPY package*.json ./

# Install production dependencies only
RUN npm ci --only=production

# ─────────────────────────────────────────────
# Stage 2: Runtime
# ─────────────────────────────────────────────
FROM node:18.15.0-alpine AS runtime

# Install wget for healthcheck
RUN apk add --no-cache wget

# Create non-root user/group for security
RUN addgroup -S appgroup && adduser -S appuser -G appgroup

WORKDIR /app

# Create data directory for SQLite and set permissions before switching user
RUN mkdir -p /app/data && chown -R appuser:appgroup /app

# Copy production dependencies from deps stage
COPY --from=deps --chown=appuser:appgroup /app/node_modules ./node_modules

# Copy application source code
COPY --chown=appuser:appgroup . .

# ─── Environment Variables ───
ENV NODE_ENV=production
ENV PORT=8000
ENV DATABASE_NAME=/app/data/dev.sqlite
ENV DATABASE_USER=user
ENV DATABASE_PASSWORD=password

# Expose application port
EXPOSE 8000

# Health check — verifica que el endpoint /api/users responde
HEALTHCHECK --interval=30s --timeout=10s --start-period=15s --retries=3 \
  CMD wget --quiet --tries=1 --spider http://localhost:${PORT}/api/users || exit 1

# Switch to non-root user
USER appuser

# Start the application
CMD ["node", "index.js"]
