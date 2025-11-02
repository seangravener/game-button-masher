#!/bin/bash
# Quick manual certificate obtainer (bypasses compose)

set -e

if [ -z "$1" ] || [ -z "$2" ]; then
    echo "Usage: ./obtain-cert.sh YOUR_DOMAIN YOUR_EMAIL"
    echo "Example: ./obtain-cert.sh smasher.odysseycreative.org domains@sageleafsystems.com"
    exit 1
fi

DOMAIN=$1
EMAIL=$2

# Create directories
mkdir -p certbot/www certbot/conf

# Detect compose command
if command -v podman &> /dev/null; then
    CONTAINER_CMD="podman"
elif command -v docker &> /dev/null; then
    CONTAINER_CMD="docker"
else
    echo "Error: Neither podman nor docker found!"
    exit 1
fi

echo "Using: $CONTAINER_CMD"
echo "Domain: $DOMAIN"
echo "Email: $EMAIL"
echo ""
echo "Obtaining certificate..."
echo ""

# Run certbot directly with proper entrypoint
$CONTAINER_CMD run --rm \
    -v "$(pwd)/certbot/www:/var/www/certbot:rw" \
    -v "$(pwd)/certbot/conf:/etc/letsencrypt:rw" \
    --network host \
    docker.io/certbot/certbot:latest \
    certonly \
    --standalone \
    --preferred-challenges http \
    --email "$EMAIL" \
    --agree-tos \
    --no-eff-email \
    -d "$DOMAIN"

echo ""
echo "✓ Certificate obtained!"
echo ""
echo "Now update nginx/conf/active.conf with SSL configuration and restart nginx."
