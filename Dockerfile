
# Use a small base image
FROM alpine:3.20

# Install required packages
RUN apk add --no-cache \
    bash \
    socat \
    coreutils \
    openssl \
    jq \
    ca-certificates

# Set working directory
WORKDIR /app

# Copy project files
COPY . .

# Make scripts executable
RUN find . -type f \( -name "*.bash" -o -name "*.sh" \) \
           -exec chmod a+x {} +

# Create sessions directory (used by session.bash)
RUN mkdir -p /app/sessions /app/data

# Create app user
RUN adduser -D appuser

# Give ownership to sessions & data directories
RUN chown -R appuser:appuser /app/sessions /app/data

# Switch user
USER appuser

# Expose the server port
EXPOSE 8080

# Environment defaults (can be overridden)
ENV HOST=127.0.0.1
ENV PORT=8080

# Start the server
ENTRYPOINT ["/bin/bash", "server.bash"]

