#!/bin/bash

# setup.sh - Automated deployment script for log-emulation project

set -euo pipefail

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m'

# Check and install dependencies
install_dependencies() {
    echo -e "${YELLOW}Installing required packages...${NC}"
    sudo zypper refresh
    sudo zypper install -y docker docker-compose python3 python3-pip
    sudo systemctl start docker
    sudo systemctl enable docker
    sudo usermod -aG docker $USER
    newgrp docker
}

# Create directory structure
create_structure() {
    echo -e "${YELLOW}Creating project structure...${NC}"
    mkdir -p {web_server,app_server,integration_server}
}

# Copy templates to target directories
copy_templates() {
    echo -e "${YELLOW}Copying templates...${NC}"
    for server_type in web app integration; do
        cp Dockerfile_template ${server_type}_server/Dockerfile
        cp log_generator_template.py ${server_type}_server/log_generator.py
        
        # Inject server type into the log generator
        sed -i "s/{{SERVER_TYPE}}/$server_type/g" ${server_type}_server/log_generator.py
    done
}

# Build and start containers
start_containers() {
    echo -e "${YELLOW}Starting containers...${NC}"
    docker-compose up -d --build
}

# Verify installation
verify_installation() {
    echo -e "${YELLOW}Verifying installation...${NC}"
    if docker-compose ps | grep -q 'Up'; then
        echo -e "${GREEN}All containers are running successfully!${NC}"
    else
        echo -e "${RED}Some containers failed to start${NC}"
        docker-compose ps
        exit 1
    fi
}

main() {
    echo -e "${YELLOW}=== Starting log-emulation deployment ===${NC}"
    
    install_dependencies
    create_structure
    copy_templates
    start_containers
    verify_installation
    
    echo -e "${GREEN}=== Deployment completed successfully ===${NC}"
    echo -e "You can now access the logs as described in init.readme"
}

main "$@"