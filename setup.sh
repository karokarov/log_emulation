#!/bin/bash

# log_emulation/deploy.sh - Fixed Deployment Script (English)

set -eo pipefail

# Colors
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m'

# Configuration
REPO_URL="https://github.com/karokarov/log_emulation.git"
PROJECT_DIR=$(basename "$(pwd)")

# Logging function
log() {
    echo -e "${YELLOW}[$(date '+%H:%M:%S')] $1${NC}"
}

# Check if we're in the correct directory
verify_location() {
    if [ "$PROJECT_DIR" != "log_emulation" ]; then
        echo -e "${RED}Error: Script must be run from log_emulation directory${NC}"
        exit 1
    fi
}

# Update project files from repository
update_project() {
    log "Updating project files..."
    
    # Stash local changes if any
    git stash push --include-untracked -m "Auto-stash for deployment"
    
    # Force pull updates
    if ! git pull --rebase origin main; then
        echo -e "${RED}Error: Failed to update project files${NC}"
        exit 1
    fi
    
    echo -e "${GREEN}✓ Project files updated${NC}"
}

# Package installation
install_packages() {
    log "Installing system dependencies..."
    
    if command -v zypper &>/dev/null; then
        sudo zypper -n refresh
        sudo zypper -n install git docker docker-compose python3 python3-pip || \
        [ $? -eq 107 ] && echo "Packages already installed"
    else
        sudo apt-get update && sudo apt-get install -y git docker.io docker-compose python3 python3-pip
    fi
    
    echo -e "${GREEN}✓ Packages installed/verified${NC}"
}

# Docker configuration
setup_docker() {
    log "Configuring Docker..."
    
    sudo systemctl enable --now docker
    sudo usermod -aG docker $USER
    
    if ! docker ps &>/dev/null; then
        echo -e "${YELLOW}Manual step required:${NC}"
        echo "  newgrp docker"
        echo "Then re-run this script"
        exit 0
    fi
    
    echo -e "${GREEN}✓ Docker configured${NC}"
}

# Project structure setup
setup_project() {
    log "Setting up project structure..."
    
    mkdir -p {web,app,integration}_server
    
    for server in web app integration; do
        cp Dockerfile_template "${server}_server/Dockerfile"
        cp log_generator_template.py "${server}_server/log_generator.py"
        sed -i "s/{{SERVER_TYPE}}/$server/g" "${server}_server/log_generator.py"
    done
    
    echo -e "${GREEN}✓ Project structure ready${NC}"
}

# Container management
manage_containers() {
    log "Starting containers..."
    
    # Stop and remove existing containers if any
    docker-compose down || true
    
    # Build and start new containers
    if ! docker-compose up -d --build; then
        echo -e "${RED}Error: Container startup failed${NC}"
        echo -e "\n${YELLOW}Diagnostic information:${NC}"
        docker-compose logs --tail=20
        exit 1
    fi
    
    # Verify container status
    unhealthy=$(docker-compose ps --services | while read -r service; do 
        if [ "$(docker-compose ps -q "$service" | xargs docker inspect -f '{{.State.Health.Status}}')" = "unhealthy" ]; then 
            echo "$service"; 
        fi
    done)
    
    if [ -n "$unhealthy" ]; then
        echo -e "${RED}Warning: Unhealthy containers detected:${NC}"
        echo "$unhealthy"
        echo -e "\n${YELLOW}Container logs:${NC}"
        docker-compose logs --tail=20 $unhealthy
    fi
    
    echo -e "${GREEN}✓ Containers running${NC}"
    docker-compose ps
}

# Main function
main() {
    echo -e "\n${YELLOW}=== Log Emulation Deployment ==="
    echo -e "Script version: 1.2 (fixed location)${NC}\n"
    
    verify_location
    update_project
    install_packages
    setup_docker
    setup_project
    manage_containers
    
    echo -e "\n${GREEN}✓ Deployment completed successfully!${NC}"
    echo -e "\nTo check logs:"
    echo "  docker exec -it web1 tail -f /var/log/web/main.log"
}

main "$@"