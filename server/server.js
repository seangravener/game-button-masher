const express = require("express");
const { createServer } = require("http");
const { Server } = require("socket.io");
const path = require("path");
const GameManager = require("./game-manager");

const app = express();
const httpServer = createServer(app);
const io = new Server(httpServer, {
  cors: {
    origin: "*",
    methods: ["GET", "POST"],
  },
});

const gameManager = new GameManager();
const PORT = process.env.PORT || 3000;

// Serve static files from the client directory
app.use(express.static(path.join(__dirname, "../client")));

app.get("/", (req, res) => {
  res.sendFile(path.join(__dirname, "../client/index.html"));
});

// Socket.IO connection handling
io.on("connection", (socket) => {
  console.log(`Client connected: ${socket.id}`);

  // Create a new room
  socket.on("create-room", (playerData, callback) => {
    const room = gameManager.createRoom();
    const result = gameManager.addPlayer(room.code, socket.id, playerData);

    if (result.success) {
      socket.join(room.code);
      callback({ success: true, roomCode: room.code });
      io.to(room.code).emit("room-update", gameManager.getRoomState(room.code));
    } else {
      callback({ success: false, error: result.error });
    }
  });

  // Join an existing room
  socket.on("join-room", (roomCode, playerData, callback) => {
    const room = gameManager.getRoom(roomCode);

    if (!room) {
      callback({ success: false, error: "Room not found" });
      return;
    }

    const result = gameManager.addPlayer(roomCode, socket.id, playerData);

    if (result.success) {
      socket.join(roomCode);
      callback({ success: true, roomCode });
      io.to(roomCode).emit("room-update", gameManager.getRoomState(roomCode));
    } else {
      callback({ success: false, error: result.error });
    }
  });

  // Toggle ready status
  socket.on("toggle-ready", (roomCode) => {
    const room = gameManager.toggleReady(roomCode, socket.id);
    if (room) {
      io.to(roomCode).emit("room-update", gameManager.getRoomState(roomCode));

      // Check if all players are ready
      if (gameManager.allPlayersReady(roomCode)) {
        // Start game after a short delay
        setTimeout(() => {
          startGameCountdown(roomCode);
        }, 1000);
      }
    }
  });

  // Handle button click during game
  socket.on("button-click", (roomCode) => {
    const room = gameManager.handleClick(roomCode, socket.id);
    if (room) {
      io.to(roomCode).emit("score-update", {
        scores: Object.fromEntries(room.scores),
      });
    }
  });

  // Reset game (play again)
  socket.on("reset-game", (roomCode) => {
    const room = gameManager.resetGame(roomCode);
    if (room) {
      io.to(roomCode).emit("room-update", gameManager.getRoomState(roomCode));
    }
  });

  // Handle disconnect
  socket.on("disconnect", () => {
    console.log(`Client disconnected: ${socket.id}`);
    const roomCode = gameManager.removePlayer(socket.id);
    if (roomCode) {
      const room = gameManager.getRoom(roomCode);
      if (room) {
        io.to(roomCode).emit("room-update", gameManager.getRoomState(roomCode));
      }
    }
  });
});

// Start game countdown
function startGameCountdown(roomCode) {
  const room = gameManager.startGame(roomCode);
  if (!room) return;

  io.to(roomCode).emit("game-starting", gameManager.getRoomState(roomCode));

  // Countdown timer (3, 2, 1)
  room.countdownTimer = setInterval(() => {
    const updatedRoom = gameManager.decrementCountdown(roomCode);
    if (!updatedRoom) {
      clearInterval(room.countdownTimer);
      return;
    }

    io.to(roomCode).emit("countdown-update", {
      countdownValue: updatedRoom.countdownValue,
    });

    if (updatedRoom.countdownValue <= 0) {
      clearInterval(room.countdownTimer);
      startGameplay(roomCode);
    }
  }, 1000);
}

// Start actual gameplay
function startGameplay(roomCode) {
  const room = gameManager.getRoom(roomCode);
  if (!room) return;

  io.to(roomCode).emit("game-started", gameManager.getRoomState(roomCode));

  // Game timer (10 seconds)
  room.gameTimer = setInterval(() => {
    const updatedRoom = gameManager.decrementTimer(roomCode);
    if (!updatedRoom) {
      clearInterval(room.gameTimer);
      return;
    }

    io.to(roomCode).emit("timer-update", {
      timeLeft: updatedRoom.timeLeft,
    });

    if (updatedRoom.timeLeft <= 0) {
      clearInterval(room.gameTimer);
      endGame(roomCode);
    }
  }, 1000);
}

// End game and show results
function endGame(roomCode) {
  const results = gameManager.getResults(roomCode);
  if (results) {
    io.to(roomCode).emit("game-ended", {
      results,
      winner: results[0],
    });
  }
}

// Start server
httpServer.listen(PORT, () => {
  console.log(`🎮 Button Masher Server running on http://localhost:${PORT}`);
});
