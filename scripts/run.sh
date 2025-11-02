#!/bin/bash

set -e

# Colors
GREEN='\033[0;32m'
BLUE='\033[0;34m'
YELLOW='\033[1;33m'
RED='\033[0;31m'
NC='\033[0m' # No Color

# Detect container runtime (Podman or Docker)
detect_runtime() {
    if command -v podman &> /dev/null; then
        CONTAINER_CMD="podman"
        if command -v podman-compose &> /dev/null; then
            COMPOSE_CMD="podman-compose"
        else
            echo -e "${RED}Error: podman-compose not found!${NC}"
            echo "Install: pip3 install podman-compose"
            exit 1
        fi
    elif command -v docker &> /dev/null; then
        CONTAINER_CMD="docker"
        if command -v docker-compose &> /dev/null; then
            COMPOSE_CMD="docker-compose"
        else
            echo -e "${RED}Error: docker-compose not found!${NC}"
            echo "Install docker-compose first"
            exit 1
        fi
    else
        echo -e "${RED}Error: Neither podman nor docker found!${NC}"
        echo "Please install Podman or Docker first"
        exit 1
    fi
}

# Show usage/help
show_help() {
    echo -e "${BLUE}🎮 Button Masher - Run Script${NC}"
    echo ""
    echo "Usage: ./scripts/run.sh [MODE]"
    echo ""
    echo -e "${GREEN}Available Modes:${NC}"
    echo "  dev          - Start local development server (default)"
    echo "  build        - Build container image"
    echo "  compose      - Run with docker-compose (HTTP only)"
    echo "  compose-ssl  - Run with docker-compose (HTTPS with SSL)"
    echo "  stop         - Stop running containers"
    echo "  logs         - View container logs (live)"
    echo "  clean        - Remove containers and images"
    echo "  help         - Show this help message"
    echo ""
    echo -e "${BLUE}Examples:${NC}"
    echo "  ./scripts/run.sh              # Start in dev mode"
    echo "  ./scripts/run.sh build        # Build container image"
    echo "  ./scripts/run.sh compose      # Run containerized (HTTP)"
    echo "  ./scripts/run.sh logs         # View container logs"
    echo ""
}

# Mode: Local Development
mode_dev() {
    echo -e "${BLUE}🎮 Button Masher - Starting Game Server${NC}"
    echo "========================================"
    echo ""

    # Check if node_modules exists
    if [ ! -d "src/server/node_modules" ]; then
        echo -e "${YELLOW}📦 Installing dependencies...${NC}"
        cd src/server
        npm install
        cd ../..
        echo ""
    fi

    echo -e "${GREEN}🚀 Starting server...${NC}"
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

    cd src/server
    npm start
}

# Mode: Build Container Image
mode_build() {
    detect_runtime

    echo -e "${BLUE}🔨 Building Container Image${NC}"
    echo "========================================"
    echo "Using: $CONTAINER_CMD"
    echo ""

    $CONTAINER_CMD build \
        -f config/docker/Dockerfile \
        -t button-smasher:latest \
        .

    echo ""
    echo -e "${GREEN}✓ Build complete!${NC}"
    echo "Image: button-smasher:latest"
    echo ""
    echo "Run with: ./scripts/run.sh compose"
}

# Mode: Run with Docker Compose (HTTP)
mode_compose() {
    detect_runtime

    echo -e "${BLUE}🚀 Starting with Docker Compose (HTTP)${NC}"
    echo "========================================"
    echo "Using: $COMPOSE_CMD"
    echo ""

    $COMPOSE_CMD -f config/docker/docker-compose.yml up -d

    echo ""
    echo -e "${GREEN}✓ Button Smasher is running!${NC}"
    echo "========================================"
    echo ""
    echo -e "Access at: ${GREEN}http://localhost:3000${NC}"
    echo ""
    echo "Useful commands:"
    echo "  View logs:  ./scripts/run.sh logs"
    echo "  Stop:       ./scripts/run.sh stop"
    echo ""
}

# Mode: Run with Docker Compose (HTTPS/SSL)
mode_compose_ssl() {
    detect_runtime

    echo -e "${BLUE}🔐 Starting with Docker Compose (SSL)${NC}"
    echo "========================================"
    echo "Using: $COMPOSE_CMD"
    echo ""

    if [ ! -d "config/nginx/conf" ] || [ ! -f "config/nginx/conf/active.conf" ]; then
        echo -e "${YELLOW}⚠ Warning: SSL not configured${NC}"
        echo ""
        echo "Run SSL setup first:"
        echo "  ./scripts/setup-ssl.sh"
        echo ""
        read -p "Continue anyway? (y/n): " continue
        if [[ "$continue" != "y" && "$continue" != "Y" ]]; then
            exit 0
        fi
    fi

    $COMPOSE_CMD -f config/docker/docker-compose.ssl.yml up -d

    echo ""
    echo -e "${GREEN}✓ Button Smasher is running with SSL!${NC}"
    echo "========================================"
    echo ""
    echo "Note: Make sure SSL certificates are configured"
    echo ""
    echo "Useful commands:"
    echo "  View logs:  ./scripts/run.sh logs"
    echo "  Stop:       ./scripts/run.sh stop"
    echo ""
}

# Mode: Stop Containers
mode_stop() {
    detect_runtime

    echo -e "${BLUE}🛑 Stopping Containers${NC}"
    echo "========================================"
    echo ""

    # Try to stop both compose files (one might not be running)
    $COMPOSE_CMD -f config/docker/docker-compose.yml down 2>/dev/null || true
    $COMPOSE_CMD -f config/docker/docker-compose.ssl.yml down 2>/dev/null || true

    echo ""
    echo -e "${GREEN}✓ Containers stopped${NC}"
}

# Mode: View Logs
mode_logs() {
    detect_runtime

    echo -e "${BLUE}📋 Container Logs${NC}"
    echo "========================================"
    echo "Press Ctrl+C to exit"
    echo ""

    # Try HTTP compose first, fall back to SSL compose
    if $COMPOSE_CMD -f config/docker/docker-compose.yml ps -q 2>/dev/null | grep -q .; then
        $COMPOSE_CMD -f config/docker/docker-compose.yml logs -f
    elif $COMPOSE_CMD -f config/docker/docker-compose.ssl.yml ps -q 2>/dev/null | grep -q .; then
        $COMPOSE_CMD -f config/docker/docker-compose.ssl.yml logs -f
    else
        echo -e "${YELLOW}No running containers found${NC}"
        echo ""
        echo "Start containers first:"
        echo "  ./scripts/run.sh compose"
    fi
}

# Mode: Clean Up
mode_clean() {
    detect_runtime

    echo -e "${YELLOW}🧹 Cleaning Up${NC}"
    echo "========================================"
    echo "This will:"
    echo "  - Stop all containers"
    echo "  - Remove containers"
    echo "  - Remove button-smasher images"
    echo ""
    read -p "Continue? (y/n): " confirm

    if [[ "$confirm" != "y" && "$confirm" != "Y" ]]; then
        echo "Cancelled"
        exit 0
    fi

    echo ""
    echo "Stopping containers..."
    $COMPOSE_CMD -f config/docker/docker-compose.yml down 2>/dev/null || true
    $COMPOSE_CMD -f config/docker/docker-compose.ssl.yml down 2>/dev/null || true

    echo "Removing images..."
    $CONTAINER_CMD rmi button-smasher:latest 2>/dev/null || true
    $CONTAINER_CMD rmi button-smasher:distroless 2>/dev/null || true

    echo ""
    echo -e "${GREEN}✓ Cleanup complete${NC}"
}

# Main execution
MODE="${1:-dev}"

case "$MODE" in
    dev)
        mode_dev
        ;;
    build)
        mode_build
        ;;
    compose)
        mode_compose
        ;;
    compose-ssl)
        mode_compose_ssl
        ;;
    stop)
        mode_stop
        ;;
    logs)
        mode_logs
        ;;
    clean)
        mode_clean
        ;;
    help|--help|-h)
        show_help
        ;;
    *)
        echo -e "${RED}Unknown mode: $MODE${NC}"
        echo ""
        show_help
        exit 1
        ;;
esac
