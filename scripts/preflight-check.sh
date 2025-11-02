#!/bin/bash
# Pre-flight checks for SSL setup
# This script validates the environment before attempting SSL certificate setup

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

# Track overall success
PREFLIGHT_PASSED=true
WARNINGS=0
ERRORS=0

echo -e "${BLUE}========================================${NC}"
echo -e "${BLUE}Pre-flight Checks for SSL Setup${NC}"
echo -e "${BLUE}========================================${NC}"
echo ""

# Function to check a requirement and track status
check_requirement() {
    local check_name="$1"
    local check_result="$2"
    local error_level="$3"  # "error" or "warning"
    local fix_message="$4"

    if [ "$check_result" = "pass" ]; then
        echo -e "${GREEN}✓${NC} $check_name"
        return 0
    else
        if [ "$error_level" = "error" ]; then
            echo -e "${RED}✗${NC} $check_name"
            ERRORS=$((ERRORS + 1))
            PREFLIGHT_PASSED=false
        else
            echo -e "${YELLOW}⚠${NC} $check_name"
            WARNINGS=$((WARNINGS + 1))
        fi

        if [ -n "$fix_message" ]; then
            echo -e "  ${BLUE}→${NC} $fix_message"
        fi
        return 1
    fi
}

echo -e "${BLUE}[1/8] Checking Container Runtime...${NC}"

# Check for podman or docker
if command -v podman &> /dev/null; then
    CONTAINER_CMD="podman"
    COMPOSE_CMD="podman-compose"
    check_requirement "Podman installed" "pass"
elif command -v docker &> /dev/null; then
    CONTAINER_CMD="docker"
    COMPOSE_CMD="docker-compose"
    check_requirement "Docker installed" "pass"
else
    check_requirement "Container runtime (podman or docker)" "fail" "error" \
        "Install podman: sudo apt install podman podman-compose"
fi

# Check for compose command
if [ -n "$COMPOSE_CMD" ]; then
    if command -v $COMPOSE_CMD &> /dev/null; then
        check_requirement "$COMPOSE_CMD installed" "pass"
    else
        check_requirement "$COMPOSE_CMD installed" "fail" "error" \
            "Install $COMPOSE_CMD"
    fi
fi

echo ""
echo -e "${BLUE}[2/8] Checking Privileged Port Access...${NC}"

# Check if running rootless and if privileged ports are accessible
if [ "$CONTAINER_CMD" = "podman" ]; then
    # Check if running rootless
    if [ -z "$SUDO_USER" ] && [ "$(id -u)" -ne 0 ]; then
        # Rootless podman - check port settings
        CURRENT_PORT_START=$(sysctl -n net.ipv4.ip_unprivileged_port_start 2>/dev/null || echo "1024")

        if [ "$CURRENT_PORT_START" -le 80 ]; then
            check_requirement "Rootless podman can bind to port 80/443" "pass"
        else
            check_requirement "Rootless podman can bind to port 80/443" "fail" "error" \
                "Run: echo 'net.ipv4.ip_unprivileged_port_start=80' | sudo tee -a /etc/sysctl.conf && sudo sysctl -p"
            echo -e "  ${BLUE}→${NC} Current setting: net.ipv4.ip_unprivileged_port_start=$CURRENT_PORT_START (needs to be ≤80)"
        fi
    else
        check_requirement "Running with sufficient privileges" "pass"
    fi
elif [ "$CONTAINER_CMD" = "docker" ]; then
    # Check if user is in docker group or running as root
    if groups | grep -q docker || [ "$(id -u)" -eq 0 ]; then
        check_requirement "Docker permissions configured" "pass"
    else
        check_requirement "Docker permissions configured" "fail" "error" \
            "Add user to docker group: sudo usermod -aG docker \$USER (then logout/login)"
    fi
fi

echo ""
echo -e "${BLUE}[3/8] Checking Port Availability...${NC}"

# Function to check if ports are used by our containers
check_project_containers() {
    if [ -n "$CONTAINER_CMD" ]; then
        # Check for any running containers with our project names
        $CONTAINER_CMD ps --format "{{.Names}}" 2>/dev/null | grep -E "button-smasher|nginx|certbot" || echo ""
    else
        echo ""
    fi
}

# Check if ports 80 and 443 are available
PORT_80_USED=$(ss -tlnp 2>/dev/null | grep ':80 ' || netstat -tlnp 2>/dev/null | grep ':80 ' || echo "")
PORT_443_USED=$(ss -tlnp 2>/dev/null | grep ':443 ' || netstat -tlnp 2>/dev/null | grep ':443 ' || echo "")
PROJECT_CONTAINERS=$(check_project_containers)

# Determine if cleanup is needed
PORTS_BLOCKED=false
if [ -n "$PORT_80_USED" ] || [ -n "$PORT_443_USED" ]; then
    PORTS_BLOCKED=true
fi

if [ "$PORTS_BLOCKED" = "true" ] && [ -n "$PROJECT_CONTAINERS" ]; then
    # Ports are blocked by our own containers - auto-cleanup
    echo -e "${YELLOW}⚠${NC} Ports in use by previous deployment"
    echo -e "  ${BLUE}→${NC} Detected containers: $PROJECT_CONTAINERS"
    echo -e "  ${BLUE}→${NC} Cleaning up stale containers..."

    # Determine compose command if not already set
    if [ -z "$COMPOSE_CMD" ]; then
        if command -v podman-compose &> /dev/null; then
            COMPOSE_CMD="podman-compose"
        elif command -v docker-compose &> /dev/null; then
            COMPOSE_CMD="docker-compose"
        fi
    fi

    # Try to clean up with compose
    CLEANUP_SUCCESS=false
    if [ -n "$COMPOSE_CMD" ]; then
        # Try SSL compose file first, then regular
        if [ -f "$PROJECT_ROOT/config/docker/docker-compose.ssl.yml" ]; then
            $COMPOSE_CMD -f "$PROJECT_ROOT/config/docker/docker-compose.ssl.yml" down &>/dev/null && CLEANUP_SUCCESS=true
        fi
        if [ "$CLEANUP_SUCCESS" = "false" ] && [ -f "$PROJECT_ROOT/config/docker/docker-compose.yml" ]; then
            $COMPOSE_CMD -f "$PROJECT_ROOT/config/docker/docker-compose.yml" down &>/dev/null && CLEANUP_SUCCESS=true
        fi
    fi

    # If compose cleanup failed, try direct container removal
    if [ "$CLEANUP_SUCCESS" = "false" ] && [ -n "$CONTAINER_CMD" ]; then
        $CONTAINER_CMD stop $PROJECT_CONTAINERS &>/dev/null || true
        $CONTAINER_CMD rm -f $PROJECT_CONTAINERS &>/dev/null || true
        CLEANUP_SUCCESS=true
    fi

    if [ "$CLEANUP_SUCCESS" = "true" ]; then
        echo -e "  ${GREEN}✓${NC} Cleanup successful"
        check_requirement "Ports 80 and 443 now available" "pass"
    else
        check_requirement "Ports 80 and 443 available" "fail" "error" \
            "Failed to clean up containers. Run: podman-compose down or docker-compose down"
    fi
elif [ "$PORTS_BLOCKED" = "true" ]; then
    # Ports blocked by external service
    if [ -n "$PORT_80_USED" ]; then
        check_requirement "Port 80 available" "fail" "warning" \
            "Port 80 is in use by external service. Stop it first: sudo systemctl stop nginx/apache2"
        echo -e "  ${BLUE}→${NC} Currently used by: $(echo "$PORT_80_USED" | head -1)"
    fi
    if [ -n "$PORT_443_USED" ]; then
        check_requirement "Port 443 available" "fail" "warning" \
            "Port 443 is in use by external service. Stop it first."
        echo -e "  ${BLUE}→${NC} Currently used by: $(echo "$PORT_443_USED" | head -1)"
    fi
else
    # Ports are free
    check_requirement "Port 80 available" "pass"
    check_requirement "Port 443 available" "pass"
fi

echo ""
echo -e "${BLUE}[4/8] Checking Required Commands...${NC}"

# Check for required system commands
for cmd in curl wget dig; do
    if command -v $cmd &> /dev/null; then
        check_requirement "$cmd installed" "pass"
    else
        check_requirement "$cmd installed" "fail" "warning" \
            "Install with: sudo apt install $cmd"
    fi
done

echo ""
echo -e "${BLUE}[5/8] Checking Internet Connectivity...${NC}"

# Check internet connectivity
if curl -s --max-time 5 https://1.1.1.1 > /dev/null 2>&1; then
    check_requirement "Internet connectivity (HTTPS)" "pass"
else
    check_requirement "Internet connectivity (HTTPS)" "fail" "error" \
        "Check your internet connection and firewall settings"
fi

# Check if Let's Encrypt is reachable
if curl -s --max-time 5 https://letsencrypt.org > /dev/null 2>&1; then
    check_requirement "Let's Encrypt API reachable" "pass"
else
    check_requirement "Let's Encrypt API reachable" "fail" "warning" \
        "Cannot reach Let's Encrypt. Certificate issuance will fail."
fi

echo ""
echo -e "${BLUE}[6/8] Checking Firewall Configuration...${NC}"

# Check if ufw is active
if command -v ufw &> /dev/null; then
    if sudo ufw status 2>/dev/null | grep -q "Status: active"; then
        # UFW is active, check if ports are allowed
        UFW_80=$(sudo ufw status 2>/dev/null | grep "80.*ALLOW" || echo "")
        UFW_443=$(sudo ufw status 2>/dev/null | grep "443.*ALLOW" || echo "")

        if [ -n "$UFW_80" ]; then
            check_requirement "UFW allows port 80" "pass"
        else
            check_requirement "UFW allows port 80" "fail" "warning" \
                "Run: sudo ufw allow 80/tcp"
        fi

        if [ -n "$UFW_443" ]; then
            check_requirement "UFW allows port 443" "pass"
        else
            check_requirement "UFW allows port 443" "fail" "warning" \
                "Run: sudo ufw allow 443/tcp"
        fi
    else
        check_requirement "UFW firewall configuration" "pass" "" "UFW not active (skipped)"
    fi
else
    check_requirement "Firewall configuration" "pass" "" "UFW not installed (skipped)"
fi

echo ""
echo -e "${BLUE}[7/8] Checking File System Permissions...${NC}"

# Check if we can create required directories
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_ROOT="$(cd "$SCRIPT_DIR/.." && pwd)"

if [ -w "$PROJECT_ROOT" ]; then
    check_requirement "Write access to project directory" "pass"
else
    check_requirement "Write access to project directory" "fail" "error" \
        "Ensure you have write permissions to $PROJECT_ROOT"
fi

# Try to create certbot directories
mkdir -p "$PROJECT_ROOT/certbot/www" "$PROJECT_ROOT/certbot/conf" 2>/dev/null
if [ -d "$PROJECT_ROOT/certbot/www" ] && [ -d "$PROJECT_ROOT/certbot/conf" ]; then
    check_requirement "Can create certbot directories" "pass"
else
    check_requirement "Can create certbot directories" "fail" "error" \
        "Cannot create directories in $PROJECT_ROOT"
fi

echo ""
echo -e "${BLUE}[8/8] Checking Container Network...${NC}"

# Check if the required network exists or can be created
if [ -n "$CONTAINER_CMD" ]; then
    NETWORK_EXISTS=$($CONTAINER_CMD network exists docker_app-network 2>/dev/null && echo "yes" || echo "no")

    if [ "$NETWORK_EXISTS" = "yes" ]; then
        check_requirement "Container network 'docker_app-network' exists" "pass"
    else
        # Try to create it
        if $CONTAINER_CMD network create docker_app-network &>/dev/null; then
            check_requirement "Container network 'docker_app-network' created" "pass"
        else
            check_requirement "Container network 'docker_app-network'" "fail" "warning" \
                "Network will be created automatically by compose"
        fi
    fi
fi

# Summary
echo ""
echo -e "${BLUE}========================================${NC}"
echo -e "${BLUE}Pre-flight Check Summary${NC}"
echo -e "${BLUE}========================================${NC}"
echo ""

if [ $ERRORS -eq 0 ] && [ $WARNINGS -eq 0 ]; then
    echo -e "${GREEN}✓ All checks passed!${NC}"
    echo -e "${GREEN}Your system is ready for SSL setup.${NC}"
    exit 0
elif [ $ERRORS -eq 0 ]; then
    echo -e "${YELLOW}⚠ $WARNINGS warning(s) found${NC}"
    echo -e "${YELLOW}SSL setup may proceed, but issues could occur.${NC}"
    echo ""
    echo -e "${BLUE}Continue anyway? (y/n):${NC} "
    read -r continue
    if [[ "$continue" = "y" || "$continue" = "Y" ]]; then
        exit 0
    else
        echo -e "${YELLOW}Setup cancelled. Please resolve warnings above.${NC}"
        exit 1
    fi
else
    echo -e "${RED}✗ $ERRORS error(s) found${NC}"
    if [ $WARNINGS -gt 0 ]; then
        echo -e "${YELLOW}⚠ $WARNINGS warning(s) found${NC}"
    fi
    echo ""
    echo -e "${RED}Please fix the errors above before proceeding with SSL setup.${NC}"
    echo ""
    echo -e "${BLUE}Common fixes:${NC}"
    echo -e "  • Rootless podman ports: echo 'net.ipv4.ip_unprivileged_port_start=80' | sudo tee -a /etc/sysctl.conf && sudo sysctl -p"
    echo -e "  • Install dependencies: sudo apt update && sudo apt install podman podman-compose curl wget dnsutils"
    echo -e "  • Check firewall: sudo ufw allow 80/tcp && sudo ufw allow 443/tcp"
    echo ""
    exit 1
fi
