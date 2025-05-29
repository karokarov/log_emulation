#!/bin/bash

# log_emulation/deploy.sh - Complete Deployment Script (English Version)

set -eo pipefail

# Colors
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m'

# Logging function
log() {
    echo -e "${YELLOW}[$(date '+%H:%M:%S')] $1${NC}"
}

# Package installation with zypper/apt compatibility
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
    
    # Docker access check
    if ! docker ps &>/dev/null; then
        echo -e "${YELLOW}Manual step required:${NC}"
        echo "  newgrp docker"
        echo "Then re-run this script"
        exit 0
    fi
    
    echo -e "${GREEN}✓ Docker configured${NC}"
}

# Project initialization
init_project() {
    log "Initializing project..."
    
    [ -d "log_emulation" ] || git clone https://github.com/karokarov/log_emulation.git
    cd log_emulation
    
    mkdir -p {web,app,integration}_server
    
    for server in web app integration; do
        cp Dockerfile_template "${server}_server/Dockerfile"
        cp log_generator_template.py "${server}_server/log_generator.py"
        sed -i "s/{{SERVER_TYPE}}/$server/g" "${server}_server/log_generator.py"
    done
    
    echo -e "${GREEN}✓ Project initialized${NC}"
}

# Container startup
start_containers() {
    log "Starting containers..."
    docker-compose up -d --build
    echo -e "${GREEN}✓ Containers running${NC}"
    docker-compose ps
}

# Main function
main() {
    echo -e "\n${YELLOW}=== Log Emulation Deployment ==="
    echo -e "Script version: 1.1 (fixed)${NC}\n"
    
    install_packages
    setup_docker
    init_project
    start_containers
    
    echo -e "\n${GREEN}✓ Deployment completed!${NC}"
    echo -e "\nTo check logs:"
    echo "  docker exec -it web1 tail -f /var/log/web/main.log"
}

main "$@"