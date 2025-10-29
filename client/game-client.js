// Connect to Socket.IO server
const socket = io();

// Game state
let currentRoom = null;
let myPlayerId = null;
let gameState = {
    status: 'join',
    players: [],
    scores: {},
    timeLeft: 10,
    countdownValue: 3
};

// Show/hide screens
function showScreen(screenName) {
    document.querySelectorAll('.join-screen, .waiting-screen, .game-screen, .results-screen')
        .forEach(screen => screen.classList.remove('active'));

    document.querySelector(`.${screenName}`).classList.add('active');
}

// Create a new room
function createRoom() {
    const playerName = document.getElementById('playerName').value.trim();
    const playerColor = document.getElementById('playerColor').value;

    if (!playerName) {
        alert('Please enter your name!');
        return;
    }

    socket.emit('create-room', { name: playerName, color: playerColor }, (response) => {
        if (response.success) {
            currentRoom = response.roomCode;
            myPlayerId = socket.id;
            document.getElementById('roomCode').textContent = currentRoom;
            showScreen('waiting-screen');
        } else {
            alert('Error creating room: ' + response.error);
        }
    });
}

// Join an existing room
function joinRoom() {
    const playerName = document.getElementById('playerName').value.trim();
    const playerColor = document.getElementById('playerColor').value;
    const roomCode = document.getElementById('roomCodeInput').value.trim().toUpperCase();

    if (!playerName) {
        alert('Please enter your name!');
        return;
    }

    if (!roomCode || roomCode.length !== 4) {
        alert('Please enter a valid 4-character room code!');
        return;
    }

    socket.emit('join-room', roomCode, { name: playerName, color: playerColor }, (response) => {
        if (response.success) {
            currentRoom = response.roomCode;
            myPlayerId = socket.id;
            document.getElementById('roomCode').textContent = currentRoom;
            showScreen('waiting-screen');
        } else {
            alert('Error joining room: ' + response.error);
        }
    });
}

// Toggle ready status
function toggleReady() {
    if (!currentRoom) return;
    socket.emit('toggle-ready', currentRoom);
}

// Handle button click during game
function clickButton(playerId) {
    if (gameState.status === 'playing' && playerId === myPlayerId) {
        socket.emit('button-click', currentRoom);
    }
}

// Play again
function playAgain() {
    if (!currentRoom) return;
    socket.emit('reset-game', currentRoom);
}

// Leave room and return to join screen
function leaveRoom() {
    location.reload();
}

// Socket.IO event handlers

// Room state update
socket.on('room-update', (roomState) => {
    gameState = roomState;

    if (roomState.status === 'waiting') {
        updateWaitingRoom(roomState);
    }
});

// Update waiting room display
function updateWaitingRoom(roomState) {
    const playersWaiting = document.getElementById('playersWaiting');
    playersWaiting.innerHTML = '';

    roomState.players.forEach(player => {
        const playerCard = document.createElement('div');
        playerCard.className = 'player-card';
        if (player.ready) {
            playerCard.classList.add('ready');
        }
        if (player.id === myPlayerId) {
            playerCard.classList.add('me');
        }

        playerCard.innerHTML = `
            <div class="player-color-badge" style="background: ${player.color}"></div>
            <div class="player-info">
                <div class="player-card-name">${player.name}${player.id === myPlayerId ? ' (You)' : ''}</div>
                <div class="player-status">${player.ready ? '✓ Ready' : 'Not Ready'}</div>
            </div>
        `;
        playersWaiting.appendChild(playerCard);
    });

    // Update ready button
    const myPlayer = roomState.players.find(p => p.id === myPlayerId);
    const readyBtn = document.getElementById('readyBtn');
    if (myPlayer && myPlayer.ready) {
        readyBtn.textContent = 'Not Ready';
        readyBtn.classList.add('ready');
    } else {
        readyBtn.textContent = 'Ready Up!';
        readyBtn.classList.remove('ready');
    }

    // Update waiting text
    const readyCount = roomState.players.filter(p => p.ready).length;
    const totalCount = roomState.players.length;
    document.getElementById('waitingText').textContent =
        `${readyCount}/${totalCount} players ready. Waiting for all players...`;
}

// Game is starting
socket.on('game-starting', (roomState) => {
    gameState = roomState;
    showScreen('game-screen');
    document.getElementById('countdown').style.display = 'block';
    document.getElementById('timer').style.display = 'none';
    document.getElementById('countdown').textContent = roomState.countdownValue;
});

// Countdown update
socket.on('countdown-update', (data) => {
    if (data.countdownValue > 0) {
        document.getElementById('countdown').textContent = data.countdownValue;
    }
});

// Game started (countdown finished)
socket.on('game-started', (roomState) => {
    gameState = roomState;
    document.getElementById('countdown').style.display = 'none';
    document.getElementById('timer').style.display = 'block';
    document.getElementById('timer').textContent = roomState.timeLeft;
    updatePlayersGrid(roomState);
});

// Timer update
socket.on('timer-update', (data) => {
    gameState.timeLeft = data.timeLeft;
    document.getElementById('timer').textContent = data.timeLeft;
});

// Score update
socket.on('score-update', (data) => {
    gameState.scores = data.scores;
    updateScores();
});

// Update players grid during game
function updatePlayersGrid(roomState) {
    const grid = document.getElementById('playersGrid');
    grid.innerHTML = '';

    roomState.players.forEach(player => {
        const box = document.createElement('div');
        box.className = 'player-box';
        if (player.id === myPlayerId) {
            box.classList.add('my-player');
        }

        box.innerHTML = `
            <div class="player-name" style="color: ${player.color}">${player.name}</div>
            <div class="player-score" id="score-${player.id}">${roomState.scores[player.id] || 0}</div>
            <button class="smash-button ${player.id !== myPlayerId ? 'disabled' : ''}"
                    style="background: ${player.color}"
                    onclick="clickButton('${player.id}')"
                    ${player.id !== myPlayerId ? 'disabled' : ''}>
                ${player.id === myPlayerId ? 'SMASH!' : player.name}
            </button>
        `;
        grid.appendChild(box);
    });
}

// Update scores during game
function updateScores() {
    Object.keys(gameState.scores).forEach(playerId => {
        const scoreElement = document.getElementById(`score-${playerId}`);
        if (scoreElement) {
            scoreElement.textContent = gameState.scores[playerId];
        }
    });
}

// Game ended
socket.on('game-ended', (data) => {
    showScreen('results-screen');
    showResults(data.results, data.winner);
});

// Show results
function showResults(results, winner) {
    document.getElementById('winnerName').textContent = `${winner.name} Wins!`;
    document.getElementById('winnerName').style.color = winner.color;

    const resultsList = document.getElementById('resultsList');
    resultsList.innerHTML = '';

    results.forEach((result, index) => {
        const item = document.createElement('div');
        item.className = 'result-item';
        if (index === 0) {
            item.classList.add('winner-item');
        }

        item.innerHTML = `
            <span class="result-rank">#${index + 1}</span>
            <span class="result-name" style="color: ${result.color}">${result.name}</span>
            <span class="result-score">${result.score} clicks</span>
        `;
        resultsList.appendChild(item);
    });
}

// Handle connection errors
socket.on('connect_error', (error) => {
    console.error('Connection error:', error);
    alert('Cannot connect to game server. Please make sure the server is running.');
});

socket.on('disconnect', () => {
    console.log('Disconnected from server');
});
