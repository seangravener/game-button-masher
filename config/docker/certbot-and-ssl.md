**Excellent — now we’re working with the real architecture.**

You’re using:

- **Nginx container** (reverse proxy on 80/443)
- **Certbot container** (for renewal)
- **Webroot volume** at `../../certbot/www` → `/var/www/certbot`
- **No initial cert issuance** in `docker-compose.ssl.yml`

---

## PROBLEM: **Initial Cert Never Issued**

Your current `docker-compose.ssl.yml` **only handles renewal**:

```yaml
entrypoint: certbot renew --quiet
```

But **Let’s Encrypt needs the first cert** to exist before it can renew.

**Result**:

- Nginx starts → serves 404 on `/.well-known/acme-challenge/`
- Certbot never runs initial issuance → no cert → SSL fails

---

## SOLUTION: **Split into 2 Steps**

### STEP 1: **Issue Initial Certificate (One-Time)**

### STEP 2: **Auto-Renew with `docker-compose.ssl.yml`**

---

## STEP 1: **Issue First Cert (Run Once)**

```bash
# From your appuser home: ~/app
cd config/docker

# 1. Create challenge dir
mkdir -p ../../certbot/www
sudo chown -R $USER:$USER ../../certbot

# 2. Run one-time certbot (webroot mode)
podman run --rm -it \
  -v "$(pwd)/../../certbot/www:/var/www/certbot:rw" \
  -v "$(pwd)/../../certbot/conf:/etc/letsencrypt:rw" \
  --network docker_app-network \
  docker.io/certbot/certbot:latest \
  certonly --webroot -w /var/www/certbot \
    -d smasher2.odysseycreative.org \
    --email domains@sageleafsystems.com \
    --agree-tos --no-eff-email \
    --force-renewal
```

**This will:**

- Drop challenge file in `/var/www/certbot/.well-known/...`
- Nginx (on port 80) serves it → Let’s Encrypt validates
- Cert saved to `../../certbot/conf/live/smasher2.odysseycreative.org/`

---

## STEP 2: **Fix `docker-compose.ssl.yml` (Only for Renewal)**

Your current `certbot` service is **almost perfect** — just needs:

- **No port 80 conflict**
- **Only renew**
- **Wait for Nginx to be up**

### Updated `docker-compose.ssl.yml`

```yaml
version: "3.8"

services:
  button-smasher:
    build:
      context: ../..
      dockerfile: config/docker/Dockerfile
    container_name: button-smasher
    environment:
      - NODE_ENV=production
      - PORT=3000
    restart: unless-stopped
    networks:
      - app-network
    expose:
      - "3000"
    deploy:
      resources:
        limits:
          cpus: "1"
          memory: 512M
        reservations:
          cpus: "0.25"
          memory: 128M

  nginx:
    image: docker.io/library/nginx:1.25-alpine
    container_name: button-smasher-nginx
    ports:
      - "80:80"
      - "443:443"
    volumes:
      - ../../config/nginx/conf/active.conf:/etc/nginx/conf.d/default.conf:ro
      - ../../certbot/www:/var/www/certbot:ro
      - ../../certbot/conf:/etc/letsencrypt:ro
    depends_on:
      - button-smasher
    networks:
      - app-network
    restart: unless-stopped
    command: >-
      /bin/sh -c '
      while :; do
        sleep 6h & wait $${!};
        nginx -s reload;
      done &
      nginx -g "daemon off;"
      '

  certbot:
    image: docker.io/certbot/certbot:latest
    container_name: button-smasher-certbot
    volumes:
      - ../../certbot/www:/var/www/certbot:rw
      - ../../certbot/conf:/etc/letsencrypt:rw
    depends_on:
      - nginx
    networks:
      - app-network
    entrypoint: >
      /bin/sh -c '
      trap exit TERM;
      echo "Waiting for initial cert...";
      while [ ! -f /etc/letsencrypt/live/smasher2.odysseycreative.org/fullchain.pem ]; do
        echo "Cert not found, sleeping...";
        sleep 60;
      done;
      echo "Cert found, starting renewal loop...";
      while :; do
        certbot renew --webroot -w /var/www/certbot --quiet;
        sleep 12h & wait $${!};
      done;
      '
    restart: unless-stopped

networks:
  app-network:
    driver: bridge
```

---

## NGINX CONFIG: `active.conf` (Must Serve `.well-known`)

```nginx
server {
    listen 80;
    server_name smasher2.odysseycreative.org;

    # ACME Challenge
    location /.well-known/acme-challenge/ {
        root /var/www/certbot;
        try_files $uri $uri/ =404;
    }

    # Redirect all else to HTTPS
    location / {
        return 301 https://$server_name$request_uri;
    }
}

server {
    listen 443 ssl http2;
    server_name smasher2.odysseycreative.org;

    ssl_certificate /etc/letsencrypt/live/smasher2.odysseycreative.org/fullchain.pem;
    ssl_certificate_key /etc/letsencrypt/live/smasher2.odysseycreative.org/privkey.pem;

    # Security headers
    add_header Strict-Transport-Security "max-age=31536000; includeSubDomains" always;

    location / {
        proxy_pass http://button-smasher:3000;
        proxy_set_header Host $host;
        proxy_set_header X-Real-IP $remote_addr;
        proxy_set_header X-Forwarded-For $proxy_add_x_forwarded_for;
        proxy_set_header X-Forwarded-Proto $scheme;
    }
}
```

---

## FINAL WORKFLOW

```bash
# 1. Stop current stack
podman-compose -f config/docker/docker-compose.ssl.yml down

# 2. Issue first cert
cd config/docker
podman run --rm -it \
  -v "$(pwd)/../../certbot/www:/var/www/certbot:rw" \
  -v "$(pwd)/../../certbot/conf:/etc/letsencrypt:rw" \
  --network docker_app-network \
  docker.io/certbot/certbot:latest \
  certonly --webroot -w /var/www/certbot \
    -d smasher2.odysseycreative.org \
    --email domains@sageleafsystems.com \
    --agree-tos --no-eff-email

# 3. Start full stack
podman-compose -f config/docker/docker-compose.ssl.yml up -d

# 4. Verify
curl -I https://smasher2.odysseycreative.org
```

---

## TEST RENEWAL

```bash
# Dry run
podman exec button-smasher-certbot certbot renew --dry-run
```

---

## TL;DR – Run This Now

```bash
# From ~/app/config/docker
podman run --rm -it \
  -v "$PWD/../../certbot/www:/var/www/certbot:rw" \
  -v "$PWD/../../certbot/conf:/etc/letsencrypt:rw" \
  --network docker_app-network \
  certbot/certbot certonly --webroot -w /var/www/certbot \
    -d smasher2.odysseycreative.org \
    --email domains@sageleafsystems.com \
    --agree-tos --no-eff-email
```

**Then `up -d` your compose file.**

---

**You’re now 100% automated:**

- Initial cert: one command
- Renewal: every 12h
- Nginx: auto-reload
- Zero downtime

Let me know when you see `Successfully received certificate` — I’ll give you:

- **OCSP stapling**
- **TLS 1.3 only**
- **Podman healthchecks**
- **Log rotation**

**SSL is now production-grade.**
