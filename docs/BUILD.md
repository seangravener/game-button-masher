# Container Build & Run Instructions

## Building the Container

### Using Podman

```bash
podman build -f config/docker/Dockerfile -t button-smasher:latest .
```

### Using Docker

```bash
docker build -f config/docker/Dockerfile -t button-smasher:latest .
```

## Running the Container

### Using Podman

```bash
# Run in foreground
podman run --rm -p 3000:3000 --name button-smasher button-smasher:latest

# Run in background (detached)
podman run -d -p 3000:3000 --name button-smasher button-smasher:latest

# Run with custom port
podman run --rm -p 8080:3000 -e PORT=3000 --name button-smasher button-smasher:latest
```

### Using Docker

```bash
# Run in foreground
docker run --rm -p 3000:3000 --name button-smasher button-smasher:latest

# Run in background (detached)
docker run -d -p 3000:3000 --name button-smasher button-smasher:latest

# Run with custom port
docker run --rm -p 8080:3000 -e PORT=3000 --name button-smasher button-smasher:latest
```

## Using Docker Compose / Podman Compose

### Using Podman Compose

```bash
# Start the service
podman-compose -f config/docker/docker-compose.yml up -d

# View logs
podman-compose -f config/docker/docker-compose.yml logs -f

# Stop the service
podman-compose -f config/docker/docker-compose.yml down
```

### Using Docker Compose

```bash
# Start the service
docker-compose -f config/docker/docker-compose.yml up -d

# View logs
docker-compose -f config/docker/docker-compose.yml logs -f

# Stop the service
docker-compose -f config/docker/docker-compose.yml down
```

## Container Management

### View running containers

```bash
podman ps        # or docker ps
```

### View logs

```bash
podman logs -f button-smasher    # or docker logs -f button-smasher
```

### Stop container

```bash
podman stop button-smasher       # or docker stop button-smasher
```

### Remove container

```bash
podman rm button-smasher         # or docker rm button-smasher
```

## Access the Application

Once running, access the game at:

- **Local**: http://localhost:3000
- **Network**: http://<your-host-ip>:3000

## Podman-Specific Features

### Run as systemd service (Podman only)

```bash
# Generate systemd unit file
podman generate systemd --name button-smasher --files

# Move to systemd directory
mkdir -p ~/.config/systemd/user/
mv container-button-smasher.service ~/.config/systemd/user/

# Enable and start service
systemctl --user enable container-button-smasher.service
systemctl --user start container-button-smasher.service
```

### Rootless mode (Podman advantage)

Podman runs rootless by default, providing better security than Docker.

## Security Features

- **Non-root user**: Application runs as user `appuser` (UID 1001)
- **Minimal base image**: Uses Alpine Linux for smaller attack surface
- **Health checks**: Built-in health monitoring
- **Production mode**: NODE_ENV set to production

## Troubleshooting

### Port already in use

If port 3000 is already taken, map to a different host port:

```bash
podman run --rm -p 8080:3000 button-smasher:latest
```

### Check container health

```bash
podman inspect button-smasher | grep -A 10 Health
```

### Interactive debugging

```bash
podman run --rm -it --entrypoint /bin/sh button-smasher:latest
```
