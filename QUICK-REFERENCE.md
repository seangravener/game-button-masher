# Quick Reference - New Project Structure

## Common Commands (Post-Refactor)

### Development

```bash
# Start development server
./scripts/start.sh

# Or manually
cd src/server && npm start

# Install dependencies
cd src/server && npm install
```

### Docker/Podman (HTTP)

```bash
# Build image
podman build -f config/docker/Dockerfile -t button-smasher:latest .

# Run with compose
podman-compose -f config/docker/docker-compose.yml up -d

# View logs
podman-compose -f config/docker/docker-compose.yml logs -f

# Stop
podman-compose -f config/docker/docker-compose.yml down
```

### SSL/HTTPS Setup

```bash
# Interactive SSL setup
./scripts/setup-ssl.sh

# Manual certificate obtainment
./scripts/obtain-cert.sh yourdomain.com you@email.com

# Run with SSL
podman-compose -f config/docker/docker-compose.ssl.yml up -d
```

### Alternative: Distroless Build

```bash
# Build with distroless (maximum security)
podman build -f config/docker/Dockerfile.distroless -t button-smasher:distroless .
```

## Project Layout

```
├── src/                    # All source code
│   ├── client/            # Frontend
│   └── server/            # Backend
├── config/                # All configuration
│   ├── docker/           # Docker configs
│   └── nginx/            # Nginx configs
├── scripts/               # Executable scripts
├── docs/                  # Documentation
└── assets/                # Static assets
```

## File Locations

| What | Old Location | New Location |
|------|-------------|--------------|
| Client files | `client/` | `src/client/` |
| Server files | `server/` | `src/server/` |
| Dockerfile | `Dockerfile` | `config/docker/Dockerfile` |
| Compose files | `docker-compose*.yml` | `config/docker/docker-compose*.yml` |
| Scripts | `*.sh` (root) | `scripts/*.sh` |
| Docs | `*.md` (root) | `docs/*.md` |
| Nginx config | `nginx/` | `config/nginx/` |

## Quick Tips

- **Use tab completion** - All paths are cleaner now
- **Check docs/** - All documentation is centralized
- **Run from root** - Always execute commands from project root
- **Read REFACTOR-SUMMARY.md** - Full migration details

## Troubleshooting

**"Command not found"**
- Scripts moved to `scripts/` - use `./scripts/start.sh`

**"File not found" in Docker**
- Use full path: `-f config/docker/docker-compose.yml`

**Old commands not working**
- Check [REFACTOR-SUMMARY.md](REFACTOR-SUMMARY.md) for updated commands
