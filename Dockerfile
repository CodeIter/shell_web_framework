
# Use a small base image
FROM alpine:3.20

# Install required packages
RUN apk add --no-cache \
    bash \
    socat \
    coreutils \
    openssl \
    jq \
    ca-certificates \
    nginx \
    perl

# Set working directory
WORKDIR /app

# Copy project files
COPY . .

# Copy and activate nginx reverse-proxy config
RUN mv -f proxy.nginx /etc/nginx/conf.d/default.conf

# Make scripts executable
RUN find . -type f \( -name "*.bash" -o -name "*.sh" \) \
           -exec chmod a+x {} +

# Create sessions & data directory
RUN mkdir -p /app/sessions /app/data

# Create app user
RUN adduser -D appuser

# Give ownership to sessions & data directories
RUN chown -R appuser:appuser /app/sessions /app/data

# Switch user
USER appuser

# Expose the server port
EXPOSE 8000

# Environment defaults (can be overridden)
ENV HOST=127.0.0.1
ENV PORT=8080

# Start the server
#   - bash server in background
#   - nginx in foreground (proper signal handling + logs)
ENTRYPOINT ["sh", "-c", "./server.bash & exec nginx -g 'daemon off;'"]

