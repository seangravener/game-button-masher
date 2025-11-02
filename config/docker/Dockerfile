# Use official Node.js LTS image with specific version for security
# Use latest patch version of Node 22 LTS on Alpine 3.20
FROM docker.io/library/node:22-alpine3.20

# Set working directory
WORKDIR /app

# Update packages and install security updates
RUN apk update && apk upgrade --no-cache

# Copy server package files
COPY src/server/package*.json ./src/server/

# Install production dependencies
WORKDIR /app/src/server
RUN npm ci --only=production

# Copy application files
WORKDIR /app
COPY src/server/ ./src/server/
COPY src/client/ ./src/client/

# Create non-root user for security
RUN addgroup -g 1001 -S appuser && \
    adduser -u 1001 -S appuser -G appuser && \
    chown -R appuser:appuser /app

# Switch to non-root user
USER appuser

# Expose the application port
EXPOSE 3000

# Set environment variable
ENV NODE_ENV=production

# Health check
HEALTHCHECK --interval=30s --timeout=3s --start-period=5s --retries=3 \
  CMD node -e "require('http').get('http://localhost:3000', (r) => {process.exit(r.statusCode === 200 ? 0 : 1)})"

# Start the server
WORKDIR /app/src/server
CMD ["node", "server.js"]
