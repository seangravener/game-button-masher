# Quick Start Guide

## Getting Started in 3 Steps

### Step 1: Install Dependencies

Open a terminal in the project directory and run:

```bash
cd server
npm install
```

### Step 2: Start the Server

```bash
npm start
```

Or use the quick start script from the project root:

```bash
./start.sh
```

### Step 3: Open in Browser

Open your browser and navigate to:

```
http://localhost:3000
```

## Testing Multiplayer Locally

### Option 1: Multiple Browser Tabs
1. Open `http://localhost:3000` in one tab
2. Click "Create New Room"
3. Note the 4-character room code
4. Open a new tab to `http://localhost:3000`
5. Enter the room code and click "Join Room"
6. Repeat for up to 4 players total

### Option 2: Multiple Browser Windows
- Open the same URL in multiple browser windows side by side
- Great for testing on one screen

### Option 3: Multiple Devices (Same Network)
1. Find your computer's local IP address:
   - **Windows**: Open cmd and type `ipconfig`
   - **Mac**: Open terminal and type `ifconfig | grep inet`
   - **Linux**: Open terminal and type `hostname -I`

2. Look for an IP like `192.168.1.XXX`

3. On other devices (phones, tablets, other computers), open:
   ```
   http://YOUR-IP-ADDRESS:3000
   ```
   Example: `http://192.168.1.100:3000`

## Common Issues

### "Cannot GET /"
- Make sure you're accessing through the server (`http://localhost:3000`)
- Don't open the HTML file directly in the browser

### "Cannot connect to server"
- Verify the server is running (you should see "Button Masher Server running...")
- Check that port 3000 isn't being used by another application

### "Room not found"
- Make sure all players are connected to the same server
- Room codes are case-insensitive but must be exactly 4 characters
- Check for typos in the room code

### CORS Errors
- Always access the game through `http://localhost:3000`, not by opening the HTML file directly
- The Socket.IO library is automatically served by the server

## Development Mode

For development with auto-reload on file changes:

```bash
cd server
npm run dev
```

This requires the `nodemon` package (included in dev dependencies).

## How the Game Works

1. **Join Screen**: Enter your name, choose a color, create or join a room
2. **Waiting Room**: Players see each other join and click "Ready Up!"
3. **Countdown**: 3-2-1 countdown when all players are ready
4. **Gameplay**: 10 seconds of button clicking madness
5. **Results**: Winner announced with full leaderboard
6. **Play Again**: Stay in the same room to play another round

## Architecture Overview

```
Browser 1 (Player 1)
       ↕ WebSocket
    Node.js Server (Socket.IO)
       ↕ WebSocket
Browser 2 (Player 2)
```

The server:
- Manages game rooms
- Synchronizes game state
- Broadcasts updates to all players
- Handles disconnections

The client:
- Displays the UI
- Sends player actions to server
- Receives and renders updates

## Next Steps

Once you have the basic game working:
1. Try playing with friends on different devices
2. Explore the code to understand how it works
3. Try modifying game parameters (timer duration, max players, etc.)
4. Add new features (see README.md for ideas)

## Need Help?

Check the main [README.md](README.md) for:
- Detailed documentation
- Troubleshooting guide
- Deployment options
- Feature enhancement ideas
