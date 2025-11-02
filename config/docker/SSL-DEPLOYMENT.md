# SSL/HTTPS Deployment Guide

## Overview

This project uses **Let's Encrypt** for free SSL certificates with automated renewal via **Certbot**. The SSL infrastructure is designed for production use with zero-downtime renewals.

## Quick Start

```bash
# From project root
./scripts/setup-ssl.sh
```

The interactive script will:

1. Validate your domain and email
2. Create necessary directories
3. Obtain SSL certificate from Let's Encrypt
4. Configure Nginx with HTTPS
5. Start all services with auto-renewal

## Architecture

### Components

```
┌─────────────────┐
│   Internet      │
└────────┬────────┘
         │ :80, :443
         ▼
┌─────────────────┐
│  Nginx          │ ← Reverse proxy, SSL termination
│  (Port 80/443)  │ ← Auto-reloads every 6h
└────────┬────────┘
         │ :3000
         ▼
┌─────────────────┐
│ Button Smasher  │ ← Node.js app with Socket.IO
│  (Port 3000)    │
└─────────────────┘

┌─────────────────┐
│  Certbot        │ ← Certificate renewal daemon
│  (Background)   │ ← Checks every 12h
└─────────────────┘
```

### Directory Structure

```
game-button-smasher/
├── config/
│   ├── docker/
│   │   ├── docker-compose.ssl.yml    # SSL-enabled compose file
│   │   └── Dockerfile                # App container
│   └── nginx/
│       └── conf/
│           ├── active.conf           # Current nginx config (generated)
│           └── http-only.conf        # HTTP-only config (fallback)
├── certbot/
│   ├── www/                          # ACME challenge directory
│   └── conf/                         # Certificate storage
│       └── live/{domain}/
│           ├── fullchain.pem         # Full certificate chain
│           ├── privkey.pem           # Private key
│           ├── cert.pem              # Certificate
│           └── chain.pem             # CA chain
└── scripts/
    └── setup-ssl.sh                  # Interactive setup script
```

## Certificate Lifecycle

### Phase 1: Initial Certificate Issuance

**Triggered by:** Running `setup-ssl.sh`

1. **Nginx starts** with HTTP-only config serving ACME challenge route
2. **Certbot runs** `certonly --webroot` to obtain certificate
3. **Let's Encrypt** places challenge file in `/var/www/certbot/.well-known/acme-challenge/`
4. **Nginx serves** challenge file on port 80
5. **Let's Encrypt validates** domain ownership
6. **Certificate issued** to `certbot/conf/live/{domain}/`
7. **Nginx reconfigured** with HTTPS and restarted

### Phase 2: Automated Renewal

**Triggered by:** Certbot container every 12 hours

1. **Certbot container waits** for initial certificate (30min timeout)
2. **Renewal daemon starts** checking every 12 hours
3. **Certbot checks** if certificate needs renewal (< 30 days until expiry)
4. **If renewal needed:**
   - Certbot performs webroot challenge
   - New certificate obtained
   - Files updated in `certbot/conf/live/{domain}/`
5. **Nginx auto-reloads** every 6 hours to pick up new certs
6. **Zero downtime** - old cert valid until nginx reload

### Certificate Validity

- **Issued for:** 90 days
- **Renewal check:** Every 12 hours
- **Renewal trigger:** < 30 days remaining
- **Nginx reload:** Every 6 hours
- **Downtime:** Zero

## Health Monitoring

### Check Service Health

```bash
# View all container health status
podman-compose -f config/docker/docker-compose.ssl.yml ps

# Expected output:
# button-smasher         healthy
# button-smasher-nginx   healthy
# button-smasher-certbot running
```

### Check Certificate Status

```bash
# View certificate details (expiry, domains, etc.)
podman-compose -f config/docker/docker-compose.ssl.yml exec certbot \
  certbot certificates

# Expected output:
# Certificate Name: yourdomain.com
# Domains: yourdomain.com
# Expiry Date: 2025-XX-XX
# Certificate Path: /etc/letsencrypt/live/yourdomain.com/fullchain.pem
```

### Test Renewal Process

```bash
# Dry-run test (doesn't actually renew)
podman-compose -f config/docker/docker-compose.ssl.yml exec certbot \
  certbot renew --dry-run --webroot -w /var/www/certbot

# Expected output includes:
# "The dry run was successful"
```

### View Logs

```bash
# All services
podman-compose -f config/docker/docker-compose.ssl.yml logs -f

# Certbot only
podman-compose -f config/docker/docker-compose.ssl.yml logs -f certbot

# Nginx only
podman-compose -f config/docker/docker-compose.ssl.yml logs -f nginx

# App only
podman-compose -f config/docker/docker-compose.ssl.yml logs -f button-smasher
```

## Troubleshooting

### Certificate Not Renewing

**Symptoms:**

- Certbot logs show renewal failures
- Certificate expiry approaching

**Solutions:**

1. **Check certbot logs:**

   ```bash
   podman-compose -f config/docker/docker-compose.ssl.yml logs certbot
   ```

2. **Verify ACME challenge route:**

   ```bash
   curl -I http://yourdomain.com/.well-known/acme-challenge/test
   # Should return 404 (not 403 or 502)
   ```

3. **Test renewal manually:**

   ```bash
   podman-compose -f config/docker/docker-compose.ssl.yml exec certbot \
     certbot renew --force-renewal --webroot -w /var/www/certbot
   ```

4. **Check nginx config:**
   ```bash
   podman-compose -f config/docker/docker-compose.ssl.yml exec nginx \
     nginx -t
   ```

### Certificate Exists But HTTPS Not Working

**Symptoms:**

- Certificate files exist in `certbot/conf/live/{domain}/`
- HTTPS returns connection error

**Solutions:**

1. **Check nginx is using correct cert paths:**

   ```bash
   cat config/nginx/conf/active.conf | grep ssl_certificate
   ```

2. **Reload nginx:**

   ```bash
   podman-compose -f config/docker/docker-compose.ssl.yml restart nginx
   ```

3. **Verify ports are accessible:**

   ```bash
   sudo netstat -tlnp | grep -E ':(80|443)'
   ```

4. **Check firewall:**
   ```bash
   sudo ufw status
   # Ensure ports 80 and 443 are allowed
   ```

### Certbot Container Not Starting

**Symptoms:**

- `podman-compose ps` shows certbot as "exited"
- Certbot logs show timeout error

**Solutions:**

1. **Check if certificate exists:**

   ```bash
   ls -la certbot/conf/live/
   ```

2. **If no certificate, run setup again:**

   ```bash
   ./scripts/setup-ssl.sh
   ```

3. **If certificate exists but certbot won't start:**

   ```bash
   # Manually verify cert files
   ls -la certbot/conf/live/*/fullchain.pem

   # Restart with fresh timeout
   podman-compose -f config/docker/docker-compose.ssl.yml restart certbot
   ```

### WebSocket Connection Failing Over HTTPS

**Symptoms:**

- Socket.IO connections fail with SSL
- Browser console shows WebSocket errors

**Solutions:**

1. **Verify nginx has WebSocket config:**

   ```bash
   cat config/nginx/conf/active.conf | grep -A2 "Upgrade"
   # Should show: proxy_set_header Upgrade $http_upgrade;
   #             proxy_set_header Connection "upgrade";
   ```

2. **Check proxy timeouts:**

   ```bash
   cat config/nginx/conf/active.conf | grep timeout
   # Should show: proxy_read_timeout 86400;
   #             proxy_send_timeout 86400;
   ```

3. **Regenerate config if missing:**
   ```bash
   ./scripts/setup-ssl.sh
   # Select your existing domain (will update config)
   ```

## Manual Operations

### Force Certificate Renewal

```bash
podman-compose -f config/docker/docker-compose.ssl.yml exec certbot \
  certbot renew --force-renewal --webroot -w /var/www/certbot
```

### Add Additional Domain

```bash
# Stop services
podman-compose -f config/docker/docker-compose.ssl.yml down

# Run certbot with new domain
podman run --rm -it \
  -v "$(pwd)/certbot/www:/var/www/certbot:rw" \
  -v "$(pwd)/certbot/conf:/etc/letsencrypt:rw" \
  --network docker_app-network \
  docker.io/certbot/certbot:latest \
  certonly --webroot -w /var/www/certbot \
    -d yourdomain.com \
    -d www.yourdomain.com \
    --email your@email.com \
    --agree-tos --no-eff-email

# Update nginx config with new domain
# Edit config/nginx/conf/active.conf

# Restart services
podman-compose -f config/docker/docker-compose.ssl.yml up -d
```

### Revoke Certificate

```bash
podman-compose -f config/docker/docker-compose.ssl.yml exec certbot \
  certbot revoke --cert-path /etc/letsencrypt/live/yourdomain.com/cert.pem
```

### Backup Certificates

```bash
# Backup entire certbot directory
tar -czf certbot-backup-$(date +%Y%m%d).tar.gz certbot/

# Restore from backup
tar -xzf certbot-backup-YYYYMMDD.tar.gz
```

## Security Best Practices

### Current Configuration

- **TLS 1.2 and 1.3** only (1.0, 1.1 disabled)
- **Strong cipher suites** (ECDHE preferred)
- **HSTS enabled** (31536000 seconds = 1 year)
- **OCSP stapling** enabled
- **Security headers:**
  - `X-Frame-Options: SAMEORIGIN`
  - `X-Content-Type-Options: nosniff`
  - `X-XSS-Protection: 1; mode=block`

### Test SSL Configuration

```bash
# Using SSL Labs (external)
# Visit: https://www.ssllabs.com/ssltest/analyze.html?d=yourdomain.com

# Using testssl.sh (local)
docker run --rm -it \
  drwetter/testssl.sh:latest \
  https://yourdomain.com
```

### Monitor Certificate Expiry

```bash
# Add to cron for email alerts
0 0 * * * /usr/bin/podman-compose -f /path/to/config/docker/docker-compose.ssl.yml exec -T certbot certbot certificates | grep -A2 "Expiry Date" | mail -s "Cert Status" admin@yourdomain.com
```

## Performance Notes

### Resource Usage

- **Nginx:** ~10MB RAM (Alpine-based)
- **Certbot:** ~5MB RAM (only during renewal checks)
- **App:** Configured limits (512MB max, 128MB reserved)

### Optimization

- **HTTP/2 enabled** for faster multiplexed connections
- **Nginx reloads gracefully** (no dropped connections)
- **Certbot runs quietly** (no performance impact)
- **Static file caching** can be added if needed

## Migration Guide

### From HTTP to HTTPS

Already handled by `setup-ssl.sh` - just run it.

### From Manual Certbot to Automated

1. **Stop manual certbot cron jobs**
2. **Copy existing certs to `certbot/conf/`**
3. **Run:** `podman-compose -f config/docker/docker-compose.ssl.yml up -d`
4. **Automated renewal takes over**

### From Docker to Podman

All compose files use `docker.io/` registry prefix - works with both.

```bash
# Just swap the command
docker-compose → podman-compose
```

## FAQ

### Q: How do I know if renewal is working?

**A:** Check certbot logs for successful renewal messages:

```bash
podman-compose -f config/docker/docker-compose.ssl.yml logs certbot | grep "renewed"
```

### Q: What happens if renewal fails?

**A:** Certbot retries every 12 hours. Certificate is valid for 90 days, renewal starts at 60 days, giving 30 days of retry buffer.

### Q: Can I use this with Cloudflare?

**A:** Yes, but ensure:

- Cloudflare SSL mode is "Full" or "Full (Strict)"
- Port 80 is accessible for ACME challenges
- Or use Cloudflare DNS validation instead

### Q: Do I need to restart nginx after renewal?

**A:** No - nginx auto-reloads every 6 hours to pick up renewed certificates.

### Q: How do I check which version of TLS is being used?

**A:**

```bash
openssl s_client -connect yourdomain.com:443 -tls1_2
openssl s_client -connect yourdomain.com:443 -tls1_3
```

## Support

### Useful Resources

- **Let's Encrypt Docs:** https://letsencrypt.org/docs/
- **Certbot Docs:** https://eff-certbot.readthedocs.io/
- **Nginx SSL Docs:** https://nginx.org/en/docs/http/configuring_https_servers.html
- **SSL Labs Test:** https://www.ssllabs.com/ssltest/

### Log Locations

- **Nginx:** `podman-compose logs nginx`
- **Certbot:** `podman-compose logs certbot`
- **App:** `podman-compose logs button-smasher`
- **Let's Encrypt logs:** `certbot/conf/letsencrypt.log`

### Emergency Rollback

```bash
# Stop SSL stack
podman-compose -f config/docker/docker-compose.ssl.yml down

# Revert to HTTP-only
cp config/nginx/conf/http-only.conf config/nginx/conf/active.conf
podman-compose -f config/docker/docker-compose.yml up -d

# Access via HTTP while troubleshooting
```

---

**Last Updated:** 2025-11-02
**Maintained by:** DevOps Team
