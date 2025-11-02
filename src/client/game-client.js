// ============================================================================
// 1. GAME STATE
// ============================================================================
// Single source of truth for the current game state
// All state changes happen here

const GameState = {
  currentRoom: null,
  myPlayerId: null,
  status: "join",
  players: [],
  scores: {},
  timeLeft: 10,
  countdownValue: 3,

  // Update methods for clarity
  setRoom(roomCode) {
    this.currentRoom = roomCode;
  },

  setPlayerId(id) {
    this.myPlayerId = id;
  },

  updateFromServer(serverState) {
    this.status = serverState.status;
    this.players = serverState.players;
    this.scores = serverState.scores || this.scores;
    this.timeLeft = serverState.timeLeft;
    this.countdownValue = serverState.countdownValue;
  },

  isMyPlayer(playerId) {
    return playerId === this.myPlayerId;
  },
};

// ============================================================================
// 2. UI MANAGER
// ============================================================================
// Handles all user interface updates and DOM manipulation
// Isolating UI logic makes it both easier to understand and modify

const UI = {
  // Screen Navigation
  // -----------------
  showScreen(screenName) {
    // Hide all screens
    document
      .querySelectorAll(
        ".join-screen, .waiting-screen, .game-screen, .results-screen"
      )
      .forEach((screen) => screen.classList.remove("active"));

    // Show requested screen
    document.querySelector(`.${screenName}`).classList.add("active");
  },

  // Waiting Room UI
  // ---------------
  updateWaitingRoom(roomState) {
    this.displayRoomCode(roomState.code);
    this.displayWaitingPlayers(roomState.players);
    this.updateReadyButton(roomState.players);
    this.updateWaitingText(roomState.players);
  },

  displayRoomCode(code) {
    document.getElementById("roomCode").textContent = code;
  },

  displayWaitingPlayers(players) {
    const container = document.getElementById("playersWaiting");
    container.innerHTML = "";

    players.forEach((player) => {
      const playerCard = this.createPlayerCard(player);
      container.appendChild(playerCard);
    });
  },

  createPlayerCard(player) {
    const card = document.createElement("div");
    card.className = "player-card";

    // Add visual states
    if (player.ready) card.classList.add("ready");
    if (GameState.isMyPlayer(player.id)) card.classList.add("me");

    card.innerHTML = `
      <div class="player-color-badge" style="background: ${player.color}"></div>
      <div class="player-info">
        <div class="player-card-name">
          ${player.name}${GameState.isMyPlayer(player.id) ? " (You)" : ""}
        </div>
        <div class="player-status">
          ${player.ready ? "✓ Ready" : "Not Ready"}
        </div>
      </div>
    `;

    return card;
  },

  updateReadyButton(players) {
    const myPlayer = players.find((p) => GameState.isMyPlayer(p.id));
    const readyBtn = document.getElementById("readyBtn");

    if (myPlayer && myPlayer.ready) {
      readyBtn.textContent = "Not Ready";
      readyBtn.classList.add("ready");
    } else {
      readyBtn.textContent = "Ready Up!";
      readyBtn.classList.remove("ready");
    }
  },

  updateWaitingText(players) {
    const readyCount = players.filter((p) => p.ready).length;
    const totalCount = players.length;
    const text = `${readyCount}/${totalCount} players ready. Waiting for all players...`;
    document.getElementById("waitingText").textContent = text;
  },

  // Countdown UI
  // ------------
  showCountdown(value) {
    document.getElementById("countdown").style.display = "block";
    document.getElementById("timer").style.display = "none";
    document.getElementById("countdown").textContent = value;
  },

  updateCountdown(value) {
    if (value > 0) {
      document.getElementById("countdown").textContent = value;
    }
  },

  // Gameplay UI
  // -----------
  showGameTimer(timeLeft) {
    document.getElementById("countdown").style.display = "none";
    document.getElementById("timer").style.display = "block";
    document.getElementById("timer").textContent = timeLeft;
  },

  updateTimer(timeLeft) {
    document.getElementById("timer").textContent = timeLeft;
  },

  displayPlayersGrid(players, scores) {
    const grid = document.getElementById("playersGrid");
    grid.innerHTML = "";

    players.forEach((player) => {
      const playerBox = this.createPlayerBox(player, scores[player.id] || 0);
      grid.appendChild(playerBox);
    });
  },

  createPlayerBox(player, score) {
    const box = document.createElement("div");
    box.className = "player-box";
    if (GameState.isMyPlayer(player.id)) {
      box.classList.add("my-player");
    }

    const isMyButton = GameState.isMyPlayer(player.id);
    const buttonClass = isMyButton ? "" : "disabled";
    const buttonDisabled = isMyButton ? "" : "disabled";
    const buttonText = isMyButton ? "SMASH!" : player.name;

    box.innerHTML = `
      <div class="player-name" style="color: ${player.color}">${player.name}</div>
      <div class="player-score" id="score-${player.id}">${score}</div>
      <button class="smash-button ${buttonClass}"
              style="background: ${player.color}"
              onclick="Game.handleClick('${player.id}')"
              ${buttonDisabled}>
        ${buttonText}
      </button>
    `;

    return box;
  },

  updateScores(scores) {
    Object.entries(scores).forEach(([playerId, score]) => {
      const scoreElement = document.getElementById(`score-${playerId}`);
      if (scoreElement) {
        scoreElement.textContent = score;
      }
    });
  },

  // Results UI
  // ----------
  displayResults(results, winner) {
    document.getElementById("winnerName").textContent = `${winner.name} Wins!`;
    document.getElementById("winnerName").style.color = winner.color;

    const resultsList = document.getElementById("resultsList");
    resultsList.innerHTML = "";

    results.forEach((result, index) => {
      const item = this.createResultItem(result, index);
      resultsList.appendChild(item);
    });
  },

  createResultItem(result, index) {
    const item = document.createElement("div");
    item.className = "result-item";
    if (index === 0) {
      item.classList.add("winner-item");
    }

    item.innerHTML = `
      <span class="result-rank">#${index + 1}</span>
      <span class="result-name" style="color: ${result.color}">${
      result.name
    }</span>
      <span class="result-score">${result.score} clicks</span>
    `;

    return item;
  },

  // User Feedback
  // -------------
  showError(message) {
    alert(message);
  },
};

// ============================================================================
// 3. ROOM MANAGER
// ============================================================================
// Handles room creation, joining, and player ready states

const Room = {
  // Create a new game room
  create() {
    const playerData = this.getPlayerData();
    if (!playerData) return;

    socket.emit("create-room", playerData, (response) => {
      if (response.success) {
        this.onRoomJoined(response.roomCode);
      } else {
        UI.showError("Error creating room: " + response.error);
      }
    });
  },

  // Join an existing room by code
  join() {
    const playerData = this.getPlayerData();
    if (!playerData) return;

    const roomCode = document
      .getElementById("roomCodeInput")
      .value.trim()
      .toUpperCase();

    if (!this.isValidRoomCode(roomCode)) {
      UI.showError("Please enter a valid 4-character room code!");
      return;
    }

    socket.emit("join-room", roomCode, playerData, (response) => {
      if (response.success) {
        this.onRoomJoined(response.roomCode);
      } else {
        UI.showError("Error joining room: " + response.error);
      }
    });
  },

  // Toggle player's ready status
  toggleReady() {
    if (!GameState.currentRoom) return;
    socket.emit("toggle-ready", GameState.currentRoom);
  },

  // Leave room and return to join screen
  leave() {
    location.reload();
  },

  // Helper Methods
  // --------------
  getPlayerData() {
    const name = document.getElementById("playerName").value.trim();
    const color = document.getElementById("playerColor").value;

    if (!name) {
      UI.showError("Please enter your name!");
      return null;
    }

    return { name, color };
  },

  isValidRoomCode(code) {
    return code && code.length === 4;
  },

  onRoomJoined(roomCode) {
    GameState.setRoom(roomCode);
    GameState.setPlayerId(socket.id);
    UI.displayRoomCode(roomCode);
    UI.showScreen("waiting-screen");
  },
};

// ============================================================================
// 4. GAME MANAGER
// ============================================================================
// Handles gameplay mechanics during the active game phase
// This is where the actual button-smashing happens!

const Game = {
  // Handle button click
  handleClick(playerId) {
    // Only allow clicking your own button during gameplay
    if (GameState.status === "playing" && GameState.isMyPlayer(playerId)) {
      socket.emit("button-click", GameState.currentRoom);
    }
  },

  // Start a new game (play again)
  playAgain() {
    if (!GameState.currentRoom) return;
    socket.emit("reset-game", GameState.currentRoom);
  },

  // Game phase handlers
  // -------------------
  onGameStarting(roomState) {
    GameState.updateFromServer(roomState);
    UI.showScreen("game-screen");
    UI.showCountdown(roomState.countdownValue);
  },

  onCountdownUpdate(countdownValue) {
    UI.updateCountdown(countdownValue);
  },

  onGameStarted(roomState) {
    GameState.updateFromServer(roomState);
    UI.showGameTimer(roomState.timeLeft);
    UI.displayPlayersGrid(roomState.players, roomState.scores);
  },

  onTimerUpdate(timeLeft) {
    GameState.timeLeft = timeLeft;
    UI.updateTimer(timeLeft);
  },

  onScoreUpdate(scores) {
    GameState.scores = scores;
    UI.updateScores(scores);
  },

  onGameEnded(results, winner) {
    UI.showScreen("results-screen");
    UI.displayResults(results, winner);
  },
};

// ============================================================================
// 5. CHAT MANAGER
// ============================================================================
// Handles chat functionality in the waiting room

const Chat = {
  // Send a chat message
  sendMessage() {
    const input = document.getElementById("chatInput");
    const message = input.value.trim();

    console.log("Chat.sendMessage called");
    console.log("Message:", message);
    console.log("Current room:", GameState.currentRoom);

    if (!message || !GameState.currentRoom) {
      console.log("Message empty or no room, returning");
      return;
    }

    // Send message to server
    console.log("Emitting chat-message to server:", {
      roomCode: GameState.currentRoom,
      message: message,
    });
    socket.emit("chat-message", {
      roomCode: GameState.currentRoom,
      message: message,
    });

    // Clear input
    input.value = "";
  },

  // Display a received chat message
  displayMessage(data) {
    console.log("Chat.displayMessage called with data:", data);
    const messagesContainer = document.getElementById("chatMessages");
    const messageDiv = document.createElement("div");
    messageDiv.className = "chat-message";

    messageDiv.innerHTML = `
      <span class="chat-message-author" style="color: ${data.color}">
        ${data.playerName}:
      </span>
      <span class="chat-message-text">${this.escapeHtml(data.message)}</span>
    `;

    messagesContainer.appendChild(messageDiv);

    // Auto-scroll to bottom
    messagesContainer.scrollTop = messagesContainer.scrollHeight;
  },

  // Escape HTML to prevent XSS
  escapeHtml(text) {
    const div = document.createElement("div");
    div.textContent = text;
    return div.innerHTML;
  },

  // Clear chat when leaving room
  clearMessages() {
    const messagesContainer = document.getElementById("chatMessages");
    if (messagesContainer) {
      messagesContainer.innerHTML = "";
    }
  },
};

// ============================================================================
// 6. SOCKET CONNECTION & EVENT HANDLERS
// ============================================================================
// Manages real-time communication with the game server
// All network events are registered here in a declarative way

const socket = io();

// Declarative Socket Event Mapping
// ---------------------------------
// This pattern makes it easy to see all events at a glance
// and understand what happens when the server sends data

const socketEventHandlers = {
  // Room Events
  "room-update": (roomState) => {
    GameState.updateFromServer(roomState);

    if (roomState.status === "waiting") {
      UI.updateWaitingRoom(roomState);
    }
  },

  // Chat Events
  "chat-message": (data) => {
    console.log("Socket received chat-message event:", data);
    Chat.displayMessage(data);
  },

  // Game Start Events
  "game-starting": (roomState) => {
    Game.onGameStarting(roomState);
  },

  "countdown-update": (data) => {
    Game.onCountdownUpdate(data.countdownValue);
  },

  "game-started": (roomState) => {
    Game.onGameStarted(roomState);
  },

  // Active Game Events
  "timer-update": (data) => {
    Game.onTimerUpdate(data.timeLeft);
  },

  "score-update": (data) => {
    Game.onScoreUpdate(data.scores);
  },

  // End Game Events
  "game-ended": (data) => {
    Game.onGameEnded(data.results, data.winner);
  },

  // Connection Events
  connect_error: (error) => {
    console.error("Connection error:", error);
    UI.showError(
      "Cannot connect to game server. Please make sure the server is running."
    );
  },

  disconnect: () => {
    console.log("Disconnected from server");
  },
};

// Register all socket event handlers
// -----------------------------------
// This loop connects each event name to its handler function
Object.entries(socketEventHandlers).forEach(([eventName, handler]) => {
  socket.on(eventName, handler);
});

// ============================================================================
// 7. GLOBAL FUNCTIONS FOR HTML ONCLICK HANDLERS
// ============================================================================
// These functions are called directly from HTML onclick attributes
// They simply delegate to the appropriate manager

function createRoom() {
  Room.create();
}

function joinRoom() {
  Room.join();
}

function toggleReady() {
  Room.toggleReady();
}

function playAgain() {
  Game.playAgain();
}

function leaveRoom() {
  Room.leave();
}

function sendChatMessage() {
  Chat.sendMessage();
}
