# Button Masher - Multiplayer Game

A real-time multiplayer button-smashing game for 2-4 players built with Socket.IO. Perfect for learning about WebSocket communication and multiplayer game development!

## Features

- Real-time multiplayer gameplay for 2-4 players
- Room-based system with unique room codes
- Waiting room with ready-up system
- Live score synchronization
- Responsive design for desktop and mobile
- Simple and intuitive UI

## How to Play

1. One player creates a new room
2. Share the 4-character room code with friends
3. Other players join using the room code
4. Each player clicks "Ready Up!"
5. When all players are ready, the game starts with a 3-second countdown
6. Click your button as fast as you can for 10 seconds
7. The player with the most clicks wins!

## Project Structure

```
game-button-smasher/
├── server/
│   ├── server.js          # Main Socket.IO server
│   ├── game-manager.js    # Game room management logic
│   └── package.json       # Server dependencies
├── client/
│   ├── index.html         # Game UI
│   ├── game-client.js     # Client-side Socket.IO logic
│   └── styles.css         # Game styles
├── button-masher.html     # Original single-device version
└── README.md
```

## Setup Instructions

### Prerequisites

- Node.js (version 14 or higher)
- npm (comes with Node.js)

### Installation

1. Navigate to the server directory:
```bash
cd server
```

2. Install dependencies:
```bash
npm install
```

### Running the Game

1. Start the server:
```bash
npm start
```

Or for development with auto-reload:
```bash
npm run dev
```

2. Open your browser and navigate to:
```
http://localhost:3000
```

3. Open multiple browser tabs or devices to test multiplayer functionality

## Server Configuration

The server runs on port 3000 by default. To change the port, set the `PORT` environment variable:

```bash
PORT=8080 npm start
```

## Socket.IO Events

### Client to Server

- `create-room` - Create a new game room
- `join-room` - Join an existing room with a code
- `toggle-ready` - Toggle player ready status
- `button-click` - Send a button click during gameplay
- `reset-game` - Reset the game to play again

### Server to Client

- `room-update` - Full room state update
- `game-starting` - Game countdown is beginning
- `countdown-update` - Countdown tick (3, 2, 1)
- `game-started` - Gameplay has started
- `timer-update` - Game timer tick
- `score-update` - Score changed during gameplay
- `game-ended` - Game finished with results

## Game States

1. **Join** - Player enters name and creates/joins room
2. **Waiting** - Players wait in lobby and ready up
3. **Countdown** - 3-2-1 countdown before game starts
4. **Playing** - 10 seconds of button clicking
5. **Finished** - Results screen with winner

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
