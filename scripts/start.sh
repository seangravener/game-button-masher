#!/bin/bash

echo "🎮 Button Masher - Starting Game Server"
echo "========================================"
echo ""

# Check if node_modules exists
if [ ! -d "src/server/node_modules" ]; then
    echo "📦 Installing dependencies..."
    cd server
    npm install
    cd ..
    echo ""
fi

echo "🚀 Starting server..."
echo "📍 Server will be available at: http://localhost:3000"
echo ""
echo "To test multiplayer:"
echo "  1. Open http://localhost:3000 in your browser"
echo "  2. Create a room and note the room code"
echo "  3. Open another tab/window and join with the code"
echo ""
echo "Press Ctrl+C to stop the server"
echo "========================================"
echo ""

cd server
npm start
