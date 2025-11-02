# Button Masher - Multiplayer Game

Welcome! This is a real-time multiplayer game where 2-4 players compete to see who can click a button the fastest. It's built with Socket.IO to teach you how real-time multiplayer games actually work.

## Why Build This?

If you've ever wondered how multiplayer games work behind the scenes, this project breaks it down into simple, understandable pieces. You'll learn:

- **How WebSockets work** - The technology that lets players communicate in real-time
- **Client-server architecture** - How one computer (server) coordinates multiple players (clients)
- **Game state management** - Keeping everyone's game in sync
- **Room-based multiplayer** - The same system used by games like Among Us or Jackbox

This isn't just following a tutorial—you'll understand the fundamental building blocks used in real multiplayer games.

## How the Game Works

1. One player creates a room and gets a 4-character code
2. Friends join using that code (up to 4 players total)
3. Everyone hits "Ready Up!" when they're in
4. After a 3-2-1 countdown, click your button as fast as you can for 10 seconds
5. Winner gets bragging rights!

## Getting Started

### What You Need

- **Node.js** installed on your computer ([download here](https://nodejs.org))
- A web browser (Chrome, Firefox, Safari—anything works)
- That's it!

### Running the Game

1. **Install the dependencies** (just once):
   ```bash
   cd server
   npm install
   ```

2. **Start the server**:
   ```bash
   npm start
   ```

   You should see `Server running on port 3000`

3. **Open your browser** and go to:
   ```
   http://localhost:3000
   ```

4. **Test multiplayer**: Open another browser tab or grab a friend's device on the same network

**Tip for beginners**: If you see "Cannot find module" errors, make sure you ran `npm install` in the `server` folder.

## What's Inside?

Here's what each file does—no mystery, just straightforward organization:

```
game-button-smasher/
├── server/
│   ├── server.js          # Where the magic happens - handles all player connections
│   ├── game-manager.js    # The referee - manages rooms, scores, and game rules
│   └── package.json       # Lists what npm needs to install
├── client/
│   ├── index.html         # What players see in their browser
│   ├── game-client.js     # Talks to the server, updates the game screen
│   └── styles.css         # Makes it look good
└── button-masher.html     # The original single-device version (see below)
```

## How Messages Flow (Socket.IO Events)

Think of Socket.IO events like text messages between players and the server. Here's what each "message" does:

**Players send to server:**

- `create-room` → "Hey, I want to start a new game room"
- `join-room` → "I want to join room ABCD"
- `toggle-ready` → "I'm ready!" (or "Wait, not ready yet")
- `button-click` → "I clicked!" (sent every time during gameplay)
- `reset-game` → "Let's play again!"

**Server broadcasts to players:**

- `room-update` → "Here's who's in the room and their status"
- `game-starting` → "Countdown is about to begin!"
- `countdown-update` → "3... 2... 1..."
- `game-started` → "GO! Start clicking!"
- `timer-update` → "9 seconds left... 8... 7..."
- `score-update` → "Player X now has 42 clicks"
- `game-ended` → "Time's up! Here's who won"

Understanding these events is key to building multiplayer games. Each one is a specific moment where the client and server need to talk to each other.

## Deployment Options

### Local Network

To play on local network, find your local IP address:

**Windows:**
```bash
ipconfig
```

**Mac/Linux:**
```bash
ifconfig
```

Then share the IP address with players (e.g., `http://192.168.1.100:3000`)

### Cloud Hosting

The game can be deployed to:

- **Glitch** - Free, beginner-friendly
- **Render** - Free tier available
- **Railway** - Simple deployment
- **Heroku** - Classic PaaS option
- **DigitalOcean** - More control
- **AWS/Azure/GCP** - Enterprise options

## Educational Use

This project is ideal for teaching:

- WebSocket communication with Socket.IO
- Real-time multiplayer game architecture
- Client-server communication patterns
- Room-based multiplayer systems
- State management across multiple clients
- Node.js and Express basics

## Comparing Versions

### Original Version (button-masher.html)
- Uses localStorage for cross-tab communication
- Only works on the same device
- Simple single-file implementation

### Multiplayer Version (current)
- Uses Socket.IO for real-time communication
- Works across different devices and networks
- Separate client and server architecture
- Room-based system with waiting rooms

## Troubleshooting

### Cannot connect to server
- Make sure the server is running (`npm start` in server directory)
- Check that you're using the correct URL
- Verify firewall isn't blocking port 3000

### Players can't join my room
- Make sure both players are connected to the same server
- Verify the room code is entered correctly (4 characters, case-insensitive)
- Check that the room isn't full (max 4 players)

### Game won't start
- All players must click "Ready Up!"
- Minimum 2 players required
- Maximum 4 players allowed

## Future Enhancements

Ideas for extending the game:

- [ ] Add configurable game duration
- [ ] Multiple game modes (survival, combo multiplier, etc.)
- [ ] Player accounts and leaderboards
- [ ] Power-ups and obstacles
- [ ] Spectator mode
- [ ] Private rooms with passwords
- [ ] Chat functionality
- [ ] Game replay system
- [ ] Mobile app version
- [ ] Tournament bracket system

## Technologies Used

- **Frontend**: HTML5, CSS3, Vanilla JavaScript
- **Backend**: Node.js, Express
- **Real-time Communication**: Socket.IO
- **Architecture**: Client-Server with WebSocket

## License

MIT License - Feel free to use this for educational purposes!

## Contributing

This is an educational project. Feel free to fork and experiment with new features!

## Credits

Built as a teaching tool for learning multiplayer game development with Socket.IO.
