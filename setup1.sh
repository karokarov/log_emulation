#!/bin/bash

# log_emulation/deploy.sh - Полное автоматическое развертывание

set -eo pipefail

# Цвета и стили
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
CYAN='\033[0;36m'
NC='\033[0m'
BOLD='\033[1m'

# Проверка прав
check_root() {
    if [ "$EUID" -ne 0 ]; then
        echo -e "${YELLOW}Запрос прав sudo...${NC}"
        sudo -v
    fi
}

# Установка пакетов
install_packages() {
    echo -e "${CYAN}1. Установка системных зависимостей...${NC}"
    
    if command -v zypper &>/dev/null; then
        sudo zypper -n refresh && sudo zypper -n install git docker docker-compose python3 python3-pip
    elif command -v apt-get &>/dev/null; then
        sudo apt-get update && sudo apt-get install -y git docker.io docker-compose python3 python3-pip
    elif command -v yum &>/dev/null; then
        sudo yum install -y git docker-ce docker-ce-cli containerd.io docker-compose-plugin python3 python3-pip
    else
        echo -e "${RED}Ошибка: Неподдерживаемый пакетный менеджер${NC}"
        exit 1
    fi

    echo -e "${GREEN}✓ Пакеты установлены${NC}"
}

# Настройка Docker
setup_docker() {
    echo -e "${CYAN}2. Настройка Docker...${NC}"
    
    sudo systemctl enable --now docker
    sudo usermod -aG docker $USER
    
    # Обход проблемы с newgrp
    if ! docker ps &>/dev/null; then
        echo -e "${YELLOW}Добавьте пользователя в группу docker:${NC}"
        echo -e "  ${BOLD}newgrp docker${NC} или перезайдите в систему"
        echo -e "${YELLOW}После этого перезапустите скрипт.${NC}"
        exit 0
    fi

    echo -e "${GREEN}✓ Docker настроен${NC}"
}

# Инициализация проекта
init_project() {
    echo -e "${CYAN}3. Инициализация проекта...${NC}"
    
    local project_dir="log_emulation"
    if [ ! -d "$project_dir" ]; then
        git clone https://github.com/karokarov/log_emulation.git
        cd "$project_dir"
    else
        cd "$project_dir"
        git pull origin main
    fi

    # Создаем структуру
    mkdir -p {web,app,integration}_server
    
    # Копируем шаблоны
    for server in web app integration; do
        cp Dockerfile_template "${server}_server/Dockerfile"
        cp log_generator_template.py "${server}_server/log_generator.py"
        sed -i "s/{{SERVER_TYPE}}/$server/g" "${server}_server/log_generator.py"
    done

    echo -e "${GREEN}✓ Проект инициализирован${NC}"
}

# Запуск контейнеров
start_containers() {
    echo -e "${CYAN}4. Запуск контейнеров...${NC}"
    
    docker-compose up -d --build
    
    echo -e "${GREEN}✓ Контейнеры запущены${NC}"
    echo -e "\n${BOLD}Проверка состояния:${NC}"
    docker-compose ps
}

# Главная функция
#ukfdyfz
main() {
    clear
    echo -e "${YELLOW}=== Полное развертывание Log Emulation ===${NC}"
    
    check_root
    install_packages
    setup_docker
    init_project
    start_containers
    
    echo -e "\n${GREEN}✓ Развертывание завершено успешно!${NC}"
    echo -e "\n${BOLD}Проверка логов:${NC}"
    echo -e "  ${CYAN}docker exec -it web1 tail -f /var/log/web/main.log${NC}"
}

main "$@"