#!/bin/bash

# log_emulation/deploy.sh - Исправленный рабочий скрипт

set -eo pipefail

# Цвета
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m'

# Логирование
log() {
    echo -e "${YELLOW}[$(date '+%H:%M:%S')] $1${NC}"
}

# Установка пакетов с игнорированием кода 107 (Nothing to do)
install_packages() {
    log "Установка пакетов..."
    
    if command -v zypper &>/dev/null; then
        sudo zypper -n refresh
        sudo zypper -n install git docker docker-compose python3 python3-pip || \
        [ $? -eq 107 ] && echo "Пакеты уже установлены"
    else
        sudo apt-get update && sudo apt-get install -y git docker.io docker-compose python3 python3-pip
    fi
    
    echo -e "${GREEN}✓ Пакеты установлены/проверены${NC}"
}

# Настройка Docker
setup_docker() {
    log "Настройка Docker..."
    
    sudo systemctl enable --now docker
    sudo usermod -aG docker $USER
    
    # Проверка доступа к Docker
    if ! docker ps &>/dev/null; then
        echo -e "${YELLOW}Выполните вручную:${NC}"
        echo "  newgrp docker"
        echo "И запустите скрипт снова"
        exit 0
    fi
    
    echo -e "${GREEN}✓ Docker настроен${NC}"
}

# Инициализация проекта
init_project() {
    log "Инициализация проекта..."
    
    [ -d "log_emulation" ] || git clone https://github.com/karokarov/log_emulation.git
    cd log_emulation
    
    mkdir -p {web,app,integration}_server
    
    for server in web app integration; do
        cp Dockerfile_template "${server}_server/Dockerfile"
        cp log_generator_template.py "${server}_server/log_generator.py"
        sed -i "s/{{SERVER_TYPE}}/$server/g" "${server}_server/log_generator.py"
    done
    
    echo -e "${GREEN}✓ Проект инициализирован${NC}"
}

# Запуск контейнеров
start_containers() {
    log "Запуск контейнеров..."
    docker-compose up -d --build
    echo -e "${GREEN}✓ Контейнеры запущены${NC}"
    docker-compose ps
}

# Главная функция
main() {
    echo -e "\n${YELLOW}=== Полное развертывание ==="
    echo -e "Версия скрипта: 1.1 (исправленная)${NC}\n"
    
    install_packages
    setup_docker
    init_project
    start_containers
    
    echo -e "\n${GREEN}✓ Развертывание завершено!${NC}"
    echo -e "\nПроверка логов:"
    echo "  docker exec -it web1 tail -f /var/log/web/main.log"
}

main "$@"