
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

# Copy and activate nginx as main config
COPY proxy.nginx /etc/nginx/nginx.conf

# Ensure nginx log directory exists (root can write)
RUN mkdir -p /var/log/nginx /var/run

# Make scripts executable
RUN find . -type f \( -name "*.bash" -o -name "*.sh" \) \
           -exec chmod a+x {} +

# Create sessions & data directory
RUN mkdir -p /app/sessions /app/data /app/tmp

# Expose the server port
EXPOSE 8000

# Environment defaults (can be overridden)
ENV BASH_HOST=127.0.0.1
ENV BASH_PORT=8080

# Start the server
#   - bash server in background
#   - nginx in foreground (proper signal handling + logs)
ENTRYPOINT ["sh", "-c", "./server.bash & exec nginx -g 'daemon off;'"]

