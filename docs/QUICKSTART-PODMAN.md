# Podman Quick Start Guide

## Starting the Application

### Option 1: Using Podman Compose (Recommended)
```bash
# Start the container in the background
podman-compose -f config/docker/docker-compose.yml up -d

# The -d flag means "detached" (runs in background)
```

### Option 2: Direct Podman Command
```bash
# First, build the image
podman build -f config/docker/Dockerfile -t button-smasher:latest .

# Then run it
podman run -d -p 3000:3000 --name button-smasher button-smasher:latest
```

## Checking if the Server is Running

### Method 1: Podman Desktop (Easiest!)
1. Open **Podman Desktop**
2. Click **"Containers"** in the left sidebar
3. Look for `button-smasher-game` (or `button-smasher`)
4. Green dot = Running ✅
5. Click the container name to see:
   - **Logs** tab: Real-time server output
   - **Inspect** tab: Container details
   - **Terminal** tab: Access container shell

### Method 2: Command Line
```bash
# List all running containers
podman ps

# You should see something like:
# CONTAINER ID  IMAGE                        COMMAND         STATUS         PORTS                   NAMES
# abc123def456  localhost/button-smasher     node server.js  Up 2 minutes   0.0.0.0:3000->3000/tcp  button-smasher-game
```

### Method 3: Check the Application
```bash
# Test with curl
curl http://localhost:3000

# Or just open in your browser:
# http://localhost:3000
```

## Viewing Logs

### Podman Desktop
1. Open **Podman Desktop**
2. Click **"Containers"**
3. Click on **button-smasher-game**
4. Click the **"Logs"** tab
5. You'll see output like: `🎮 Button Masher Server running on http://localhost:3000`

### Command Line
```bash
# View logs (live/following mode - exit with Ctrl+C)
podman logs -f button-smasher-game

# View last 50 lines
podman logs --tail 50 button-smasher-game

# View logs with timestamps
podman logs -t button-smasher-game
```

## Stopping the Application

### Using Podman Compose
```bash
podman-compose -f config/docker/docker-compose.yml down
```

### Using Podman Desktop
1. Go to **Containers**
2. Find **button-smasher-game**
3. Click the **Stop** button (■)

### Using Command Line
```bash
podman stop button-smasher-game
```

## Restarting the Application

### Podman Desktop
1. Click the **Restart** button (↻) next to the container

### Command Line
```bash
# Restart existing container
podman restart button-smasher-game

# Or stop and start fresh
podman-compose -f config/docker/docker-compose.yml down
podman-compose -f config/docker/docker-compose.yml up -d
```

## Troubleshooting

### Container is running but can't access http://localhost:3000

**Check if port is actually mapped:**
```bash
podman port button-smasher-game
# Should show: 3000/tcp -> 0.0.0.0:3000
```

**Check if something else is using port 3000:**
```bash
# Linux
sudo ss -tlnp | grep 3000

# Or try a different port
podman-compose -f config/docker/docker-compose.yml down
# Edit docker-compose.yml: change "3000:3000" to "8080:3000"
podman-compose -f config/docker/docker-compose.yml up -d
# Then access http://localhost:8080
```

### Container keeps stopping/restarting

**Check the logs for errors:**
```bash
podman logs button-smasher-game
```

**Common issues:**
- Port 3000 already in use
- Missing dependencies (rebuild: `podman-compose -f config/docker/docker-compose.yml build --no-cache`)

### Can't find the container

**List ALL containers (including stopped ones):**
```bash
podman ps -a
```

**If stopped, start it:**
```bash
podman start button-smasher-game
```

### "Permission denied" errors

**Make sure Podman is running:**
```bash
podman machine start
```

## Rebuilding After Code Changes

If you modify the code, you need to rebuild:

```bash
# Stop and remove old container
podman-compose -f config/docker/docker-compose.yml down

# Rebuild the image
podman-compose -f config/docker/docker-compose.yml build --no-cache

# Start fresh
podman-compose -f config/docker/docker-compose.yml up -d

# Check logs to confirm it's running
podman logs -f button-smasher-game
```

## Useful Podman Desktop Features

1. **Resource Usage**: See CPU/Memory usage in real-time
2. **Logs**: Color-coded, searchable logs
3. **Terminal**: Execute commands inside the container
4. **Inspect**: View all container configuration
5. **One-click actions**: Start, stop, restart, delete

## Quick Reference Card

```bash
# Start
podman-compose -f config/docker/docker-compose.yml up -d

# Check status
podman ps

# View logs
podman logs -f button-smasher-game

# Stop
podman-compose -f config/docker/docker-compose.yml down

# Rebuild
podman-compose -f config/docker/docker-compose.yml build --no-cache

# Access app
http://localhost:3000
```

## Pro Tips

1. **Keep Podman Desktop open** when developing - it auto-refreshes
2. **Use the Logs tab** in Podman Desktop instead of CLI
3. **Bookmark http://localhost:3000** for quick access
4. **Enable Desktop Notifications** in Podman Desktop settings for container events
5. **Use "Restart"** instead of "Stop then Start" - it's faster

## Still Having Issues?

1. Check Podman is running: `podman machine list`
2. Restart Podman machine: `podman machine restart`
3. Check Podman Desktop is connected to the machine
4. View container events: `podman events --filter container=button-smasher-game`

---

**Remember**: Podman Desktop makes everything visual - use it! It's much easier than memorizing CLI commands when you're starting out.
