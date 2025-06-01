#!/bin/bash

# log_emulation/deploy.sh - Robust Deployment Script with Container Diagnostics

set -eo pipefail

# Colors
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m'

# Configuration
REPO_URL="https://github.com/karokarov/log_emulation.git"

# Verify we're in the correct directory
if [ "$(basename "$(pwd)")" != "log_emulation" ]; then
    echo -e "${RED}Error: Must run from log_emulation directory${NC}"
    exit 1
fi

# Update project files
echo -e "${YELLOW}Updating project files...${NC}"
git stash push --include-untracked -m "Deployment stash" >/dev/null
git pull --rebase origin main || {
    echo -e "${RED}Error: Failed to update project files${NC}"
    exit 1
}
echo -e "${GREEN}✓ Files updated${NC}"

# Install packages (if not already installed)
echo -e "${YELLOW}Checking dependencies...${NC}"
if command -v zypper &>/dev/null; then
    sudo zypper -n install -l git docker docker-compose python3 python3-pip || \
    [ $? -eq 107 ] && echo "Packages already installed"
else
    sudo apt-get update && sudo apt-get install -y git docker.io docker-compose python3 python3-pip
fi
echo -e "${GREEN}✓ Dependencies checked${NC}"

# Configure Docker
echo -e "${YELLOW}Configuring Docker...${NC}"
sudo systemctl enable --now docker
sudo usermod -aG docker $USER
if ! docker ps &>/dev/null; then
    echo -e "${YELLOW}Run this command then restart script:${NC}"
    echo "  newgrp docker"
    exit 0
fi
echo -e "${GREEN}✓ Docker ready${NC}"

# Setup project structure
echo -e "${YELLOW}Preparing project...${NC}"
mkdir -p {web,app,integration}_server
for server in web app integration; do
    cp Dockerfile_template "${server}_server/Dockerfile"
    cp log_generator_template.py "${server}_server/log_generator.py"
    sed -i "s/{{SERVER_TYPE}}/$server/g" "${server}_server/log_generator.py"
done
echo -e "${GREEN}✓ Project prepared${NC}"

# Container management with enhanced diagnostics
echo -e "${YELLOW}Starting containers...${NC}"
docker-compose down 2>/dev/null || true

if ! docker-compose up -d --build; then
    echo -e "\n${RED}Container startup failed. Diagnostics:${NC}"
    echo -e "\n${YELLOW}Last logs from each service:${NC}"
    docker-compose logs --tail=20
    
    echo -e "\n${YELLOW}Failed container details:${NC}"
    docker-compose ps | grep -v "Up" | while read line; do
        container_id=$(echo $line | awk '{print $1}')
        service=$(echo $line | awk '{print $1}' | xargs docker inspect --format '{{index .Config.Labels "com.docker.compose.service"}}')
        
        echo -e "\nService: ${service}"
        echo "Exit Code: $(docker inspect -f '{{.State.ExitCode}}' ${container_id})"
        echo "Error: $(docker inspect -f '{{.State.Error}}' ${container_id})"
        echo "Logs:"
        docker logs --tail=20 ${container_id} 2>&1 | sed 's/^/  /'
    done
    
    exit 1
fi

# Verify all containers are healthy
echo -e "${YELLOW}Checking container health...${NC}"
failed_containers=$(docker-compose ps -q | xargs docker inspect -f '{{if .State.Health}}{{if ne .State.Health.Status "healthy"}}{{.Name}}{{end}}{{end}}' | sed 's|/||')

if [ -n "$failed_containers" ]; then
    echo -e "\n${RED}Unhealthy containers detected:${NC}"
    for container in $failed_containers; do
        service=$(docker inspect -f '{{index .Config.Labels "com.docker.compose.service"}}' $container)
        echo -e "\nService: ${service}"
        echo "Status: $(docker inspect -f '{{.State.Health.Status}}' $container)"
        echo "Logs:"
        docker logs --tail=30 $container 2>&1 | sed 's/^/  /'
    done
    exit 1
fi

echo -e "${GREEN}✓ All containers running and healthy${NC}"
docker-compose ps

# Initialize MinIO structure
echo -e "${YELLOW}Initializing MinIO structure...${NC}"
sleep 10  # Wait for MinIO to start

docker-compose exec minio mc alias set local http://minio:9000 admin password123 && \
docker-compose exec minio mc mb local/APP/simple || true && \
docker-compose exec minio mc mb local/APP/blog || true && \
docker-compose exec minio mc mb local/WEB/simple || true && \
docker-compose exec minio mc mb local/WEB/blog || true && \
docker-compose exec minio mc mb local/INT/simple || true && \
docker-compose exec minio mc mb local/INT/blog || true && {
  echo -e "${GREEN}✓ MinIO structure initialized${NC}"
} || {
  echo -e "${RED}Error: Failed to initialize MinIO structure${NC}"
  docker-compose logs minio
  exit 1
}

# Initialize Elasticsearch indices
echo -e "${YELLOW}Creating Elasticsearch indices...${NC}"
until curl -s -X GET "http://localhost:9200/_cluster/health" >/dev/null; do sleep 5; done
for index in $(yq e '.elasticsearch.indices[]' minio_config.yml); do
  curl -s -X PUT "http://localhost:9200/$index" -H 'Content-Type: application/json' -d'
  {
    "settings": {
      "number_of_shards": 1,
      "number_of_replicas": 0
    },
    "mappings": {
      "properties": {
        "@timestamp": {"type": "date"},
        "message": {"type": "text"},
        "server_type": {"type": "keyword"},
        "log_type": {"type": "keyword"}
      }
    }
  }' || echo "Index $index may already exist"
done
echo -e "${GREEN}✓ Elasticsearch indices created${NC}"


echo -e "\n${GREEN}Deployment successful!${NC}"
echo -e "\nAccess:"
echo "MinIO Console: http://192.168.0.4:9001"
echo "Kibana: http://192.168.0.4:5601"
echo -e "\nTo check logs:"
echo "docker exec -it web1 tail -f /var/log/web/main.log"