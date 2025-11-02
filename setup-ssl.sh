#!/bin/bash
set -e

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

echo -e "${BLUE}========================================${NC}"
echo -e "${BLUE}Button Smasher SSL Setup with Let's Encrypt${NC}"
echo -e "${BLUE}========================================${NC}"
echo ""

# Check if running with podman or docker
if command -v podman-compose &> /dev/null; then
    COMPOSE_CMD="podman-compose"
    echo -e "${GREEN}✓ Using Podman Compose${NC}"
elif command -v docker-compose &> /dev/null; then
    COMPOSE_CMD="docker-compose"
    echo -e "${GREEN}✓ Using Docker Compose${NC}"
else
    echo -e "${RED}✗ Error: Neither podman-compose nor docker-compose found!${NC}"
    echo "Please install one of them first."
    exit 1
fi

# Ask user for SSL preference
echo ""
echo -e "${YELLOW}Do you want to set up HTTPS with Let's Encrypt SSL?${NC}"
echo "Requirements:"
echo "  1. You have a domain name (e.g., game.example.com)"
echo "  2. The domain points to this server's public IP"
echo "  3. Ports 80 and 443 are open and accessible from the internet"
echo ""
read -p "Enable SSL? (y/n): " enable_ssl

if [[ "$enable_ssl" != "y" && "$enable_ssl" != "Y" ]]; then
    echo -e "${BLUE}Setting up HTTP-only configuration...${NC}"

    # Use simple HTTP configuration
    cp nginx/conf/http-only.conf nginx/conf/active.conf

    echo -e "${GREEN}✓ HTTP configuration created${NC}"
    echo ""
    echo -e "${BLUE}Starting services...${NC}"
    $COMPOSE_CMD -f docker-compose.yml up -d

    echo ""
    echo -e "${GREEN}========================================${NC}"
    echo -e "${GREEN}✓ Button Smasher is running!${NC}"
    echo -e "${GREEN}========================================${NC}"
    echo ""
    echo -e "Access your game at: ${BLUE}http://localhost:3000${NC}"
    echo -e "Or from network: ${BLUE}http://<your-ip>:3000${NC}"
    echo ""
    echo "Run this script again anytime to enable SSL."
    exit 0
fi

# SSL Setup
echo ""
echo -e "${BLUE}========================================${NC}"
echo -e "${BLUE}SSL Configuration${NC}"
echo -e "${BLUE}========================================${NC}"
echo ""

# Get domain
while true; do
    read -p "Enter your domain name (e.g., game.example.com): " DOMAIN
    if [[ -z "$DOMAIN" ]]; then
        echo -e "${RED}Domain cannot be empty!${NC}"
        continue
    fi

    # Validate domain format
    if [[ ! "$DOMAIN" =~ ^[a-zA-Z0-9][a-zA-Z0-9-]{0,61}[a-zA-Z0-9]?\.[a-zA-Z]{2,}$ ]]; then
        echo -e "${YELLOW}Warning: Domain format looks unusual. Make sure it's correct.${NC}"
    fi

    echo -e "${BLUE}Checking if domain resolves to this server...${NC}"
    DOMAIN_IP=$(dig +short "$DOMAIN" | tail -n1)
    if [[ -z "$DOMAIN_IP" ]]; then
        echo -e "${YELLOW}⚠ Warning: Domain does not resolve to any IP${NC}"
        read -p "Continue anyway? (y/n): " continue
        if [[ "$continue" != "y" ]]; then
            continue
        fi
    else
        echo -e "${GREEN}✓ Domain resolves to: $DOMAIN_IP${NC}"
    fi
    break
done

# Get email
while true; do
    read -p "Enter your email for Let's Encrypt notifications: " EMAIL
    if [[ -z "$EMAIL" ]]; then
        echo -e "${RED}Email cannot be empty!${NC}"
        continue
    fi

    if [[ ! "$EMAIL" =~ ^[a-zA-Z0-9._%+-]+@[a-zA-Z0-9.-]+\.[a-zA-Z]{2,}$ ]]; then
        echo -e "${YELLOW}Warning: Email format looks invalid${NC}"
        read -p "Continue anyway? (y/n): " continue
        if [[ "$continue" != "y" ]]; then
            continue
        fi
    fi
    break
done

# Create necessary directories
echo ""
echo -e "${BLUE}Creating certificate directories...${NC}"
mkdir -p certbot/www
mkdir -p certbot/conf

# Create initial Nginx config for ACME challenge (HTTP only)
echo -e "${BLUE}Setting up initial Nginx configuration...${NC}"
cat > nginx/conf/active.conf << 'EOF'
upstream button_smasher {
    server button-smasher:3000;
}

server {
    listen 80;
    listen [::]:80;
    server_name DOMAIN_PLACEHOLDER;

    location /.well-known/acme-challenge/ {
        root /var/www/certbot;
    }

    location / {
        return 301 https://$host$request_uri;
    }
}
EOF

# Replace domain placeholder
sed -i "s/DOMAIN_PLACEHOLDER/$DOMAIN/g" nginx/conf/active.conf

echo -e "${GREEN}✓ Initial configuration created${NC}"

# Start services with HTTP only first
echo ""
echo -e "${BLUE}Starting services for certificate generation...${NC}"
$COMPOSE_CMD -f docker-compose.ssl.yml up -d button-smasher nginx

# Wait for nginx to be ready
echo -e "${BLUE}Waiting for Nginx to be ready...${NC}"
sleep 5

# Obtain SSL certificate
echo ""
echo -e "${BLUE}========================================${NC}"
echo -e "${BLUE}Obtaining SSL Certificate${NC}"
echo -e "${BLUE}========================================${NC}"
echo ""
echo "This may take a minute..."
echo ""

if $COMPOSE_CMD -f docker-compose.ssl.yml run --rm \
    --entrypoint certbot \
    certbot certonly \
    --webroot \
    --webroot-path=/var/www/certbot \
    --email "$EMAIL" \
    --agree-tos \
    --no-eff-email \
    --force-renewal \
    -d "$DOMAIN"; then

    echo ""
    echo -e "${GREEN}✓ SSL certificate obtained successfully!${NC}"

    # Create full Nginx config with SSL
    echo -e "${BLUE}Updating Nginx configuration with SSL...${NC}"
    cat > nginx/conf/active.conf << 'EOF'
upstream button_smasher {
    server button-smasher:3000;
}

# HTTP - Redirect to HTTPS
server {
    listen 80;
    listen [::]:80;
    server_name DOMAIN_PLACEHOLDER;

    location /.well-known/acme-challenge/ {
        root /var/www/certbot;
    }

    location / {
        return 301 https://$host$request_uri;
    }
}

# HTTPS - Main application
server {
    listen 443 ssl http2;
    listen [::]:443 ssl http2;
    server_name DOMAIN_PLACEHOLDER;

    # SSL certificates
    ssl_certificate /etc/letsencrypt/live/DOMAIN_PLACEHOLDER/fullchain.pem;
    ssl_certificate_key /etc/letsencrypt/live/DOMAIN_PLACEHOLDER/privkey.pem;

    # SSL configuration
    ssl_protocols TLSv1.2 TLSv1.3;
    ssl_ciphers 'ECDHE-ECDSA-AES128-GCM-SHA256:ECDHE-RSA-AES128-GCM-SHA256:ECDHE-ECDSA-AES256-GCM-SHA384:ECDHE-RSA-AES256-GCM-SHA384';
    ssl_prefer_server_ciphers off;
    ssl_session_cache shared:SSL:10m;
    ssl_session_timeout 10m;
    ssl_stapling on;
    ssl_stapling_verify on;

    # Security headers
    add_header Strict-Transport-Security "max-age=31536000; includeSubDomains" always;
    add_header X-Frame-Options "SAMEORIGIN" always;
    add_header X-Content-Type-Options "nosniff" always;
    add_header X-XSS-Protection "1; mode=block" always;

    # Proxy to application
    location / {
        proxy_pass http://button_smasher;
        proxy_http_version 1.1;

        # WebSocket support for Socket.IO
        proxy_set_header Upgrade $http_upgrade;
        proxy_set_header Connection "upgrade";

        # Standard proxy headers
        proxy_set_header Host $host;
        proxy_set_header X-Real-IP $remote_addr;
        proxy_set_header X-Forwarded-For $proxy_add_x_forwarded_for;
        proxy_set_header X-Forwarded-Proto $scheme;

        # Timeouts for WebSocket
        proxy_read_timeout 86400;
        proxy_send_timeout 86400;
    }
}
EOF

    # Replace domain placeholders
    sed -i "s/DOMAIN_PLACEHOLDER/$DOMAIN/g" nginx/conf/active.conf

    echo -e "${GREEN}✓ SSL configuration created${NC}"

    # Restart services with full configuration
    echo ""
    echo -e "${BLUE}Restarting services with SSL...${NC}"
    $COMPOSE_CMD -f docker-compose.ssl.yml down
    $COMPOSE_CMD -f docker-compose.ssl.yml up -d

    echo ""
    echo -e "${GREEN}========================================${NC}"
    echo -e "${GREEN}✓ SSL Setup Complete!${NC}"
    echo -e "${GREEN}========================================${NC}"
    echo ""
    echo -e "${GREEN}Your Button Smasher game is now running with HTTPS!${NC}"
    echo ""
    echo -e "Access your game at: ${BLUE}https://$DOMAIN${NC}"
    echo ""
    echo -e "${YELLOW}Important Notes:${NC}"
    echo "• SSL certificates auto-renew every 12 hours"
    echo "• HTTP traffic is automatically redirected to HTTPS"
    echo "• Make sure your firewall allows ports 80 and 443"
    echo ""
    echo -e "${BLUE}Useful Commands:${NC}"
    echo "  View logs:     $COMPOSE_CMD -f docker-compose.ssl.yml logs -f"
    echo "  Stop services: $COMPOSE_CMD -f docker-compose.ssl.yml down"
    echo "  Restart:       $COMPOSE_CMD -f docker-compose.ssl.yml restart nginx"
    echo ""

else
    echo ""
    echo -e "${RED}========================================${NC}"
    echo -e "${RED}✗ SSL Certificate Failed${NC}"
    echo -e "${RED}========================================${NC}"
    echo ""
    echo -e "${YELLOW}Common issues:${NC}"
    echo "1. Domain doesn't point to this server's IP"
    echo "2. Ports 80/443 are not accessible from internet"
    echo "3. Firewall is blocking connections"
    echo "4. DNS changes haven't propagated yet (wait 5-10 minutes)"
    echo ""
    echo -e "${BLUE}Falling back to HTTP-only mode...${NC}"

    cp nginx/conf/http-only.conf nginx/conf/active.conf
    $COMPOSE_CMD -f docker-compose.yml up -d

    echo ""
    echo "Your game is running on HTTP at: http://<your-ip>:3000"
    echo "Fix the issues above and run this script again to enable SSL."
    exit 1
fi
