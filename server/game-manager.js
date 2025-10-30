class GameManager {
  constructor() {
    this.rooms = new Map();
  }

  // Generate a random 4-character room code
  generateRoomCode() {
    const chars = "ABCDEFGHJKLMNPQRSTUVWXYZ23456789";
    let code = "";
    for (let i = 0; i < 4; i++) {
      code += chars.charAt(Math.floor(Math.random() * chars.length));
    }
    return code;
  }

  // Create a new game room
  createRoom() {
    let roomCode;
    do {
      roomCode = this.generateRoomCode();
    } while (this.rooms.has(roomCode));

    const room = {
      code: roomCode,
      players: new Map(),
      status: "waiting", // waiting, countdown, playing, finished
      scores: new Map(),
      timeLeft: 10,
      countdownValue: 3,
      maxPlayers: 4,
      gameTimer: null,
      countdownTimer: null,
    };

    this.rooms.set(roomCode, room);
    console.log(`Room created: ${roomCode}`);
    return room;
  }

  // Get a room by code
  getRoom(roomCode) {
    return this.rooms.get(roomCode);
  }

  // Add player to room
  addPlayer(roomCode, socketId, playerData) {
    const room = this.rooms.get(roomCode);
    if (!room) return { success: false, error: "Room not found" };

    if (room.players.size >= room.maxPlayers) {
      return { success: false, error: "Room is full" };
    }

    if (room.status !== "waiting") {
      return { success: false, error: "Game already in progress" };
    }

    room.players.set(socketId, {
      id: socketId,
      name: playerData.name,
      color: playerData.color,
      ready: false,
    });

    room.scores.set(socketId, 0);

    console.log(`Player ${playerData.name} joined room ${roomCode}`);
    return { success: true, room };
  }

  // Remove player from room
  removePlayer(socketId) {
    for (const [roomCode, room] of this.rooms.entries()) {
      if (room.players.has(socketId)) {
        room.players.delete(socketId);
        room.scores.delete(socketId);
        console.log(`Player ${socketId} left room ${roomCode}`);

        // Clean up empty rooms
        if (room.players.size === 0) {
          this.clearTimers(roomCode);
          this.rooms.delete(roomCode);
          console.log(`Room ${roomCode} deleted (empty)`);
        } else {
          // Reset ready status if in waiting
          if (room.status === "waiting") {
            room.players.forEach((player) => (player.ready = false));
          }
        }
        return roomCode;
      }
    }
    return null;
  }

  // Toggle player ready status
  toggleReady(roomCode, socketId) {
    const room = this.rooms.get(roomCode);
    if (!room || room.status !== "waiting") return null;

    const player = room.players.get(socketId);
    if (!player) return null;

    player.ready = !player.ready;
    console.log(`Player ${player.name} ready status: ${player.ready}`);
    return room;
  }

  // Check if all players are ready
  allPlayersReady(roomCode) {
    const room = this.rooms.get(roomCode);
    if (!room || room.players.size < 2) return false;

    for (const player of room.players.values()) {
      if (!player.ready) return false;
    }
    return true;
  }

  // Start game countdown
  startGame(roomCode) {
    const room = this.rooms.get(roomCode);
    if (!room) return null;

    room.status = "countdown";
    room.countdownValue = 3;

    // Reset scores
    room.scores.forEach((_, socketId) => {
      room.scores.set(socketId, 0);
    });

    console.log(`Game starting in room ${roomCode}`);
    return room;
  }

  // Update countdown
  decrementCountdown(roomCode) {
    const room = this.rooms.get(roomCode);
    if (!room) return null;

    room.countdownValue--;
    if (room.countdownValue <= 0) {
      room.status = "playing";
      room.timeLeft = 10;
    }
    return room;
  }

  // Update game timer
  decrementTimer(roomCode) {
    const room = this.rooms.get(roomCode);
    if (!room) return null;

    room.timeLeft--;
    if (room.timeLeft <= 0) {
      room.status = "finished";
      this.clearTimers(roomCode);
    }
    return room;
  }

  // Handle button click
  handleClick(roomCode, socketId) {
    const room = this.rooms.get(roomCode);
    if (!room || room.status !== "playing") return null;

    const currentScore = room.scores.get(socketId) || 0;
    room.scores.set(socketId, currentScore + 1);
    return room;
  }

  // Get game results
  getResults(roomCode) {
    const room = this.rooms.get(roomCode);
    if (!room) return null;

    const results = [];
    room.players.forEach((player, socketId) => {
      results.push({
        id: socketId,
        name: player.name,
        color: player.color,
        score: room.scores.get(socketId) || 0,
      });
    });

    results.sort((a, b) => b.score - a.score);
    return results;
  }

  // Reset game to waiting state
  resetGame(roomCode) {
    const room = this.rooms.get(roomCode);
    if (!room) return null;

    this.clearTimers(roomCode);
    room.status = "waiting";
    room.timeLeft = 10;
    room.countdownValue = 3;
    room.players.forEach((player) => (player.ready = false));
    room.scores.forEach((_, socketId) => {
      room.scores.set(socketId, 0);
    });

    console.log(`Room ${roomCode} reset to waiting`);
    return room;
  }

  // Clear all timers for a room
  clearTimers(roomCode) {
    const room = this.rooms.get(roomCode);
    if (!room) return;

    if (room.gameTimer) {
      clearInterval(room.gameTimer);
      room.gameTimer = null;
    }
    if (room.countdownTimer) {
      clearInterval(room.countdownTimer);
      room.countdownTimer = null;
    }
  }

  // Get room state for client
  getRoomState(roomCode) {
    const room = this.rooms.get(roomCode);
    if (!room) return null;

    return {
      code: roomCode,
      status: room.status,
      players: Array.from(room.players.values()),
      scores: Object.fromEntries(room.scores),
      timeLeft: room.timeLeft,
      countdownValue: room.countdownValue,
      maxPlayers: room.maxPlayers,
    };
  }
}

module.exports = GameManager;
