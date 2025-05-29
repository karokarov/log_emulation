import os
import random
import time
from datetime import datetime
import uuid
import logging
from logging.handlers import RotatingFileHandler

# Конфигурация сервера
server_type = os.environ.get('SERVER_TYPE', 'web')
container_name = os.environ.get('HOSTNAME', '')

# Определяем тип сервера по имени контейнера
if 'web' in container_name:
    server_type = 'web'
elif 'app' in container_name:
    server_type = 'app'
elif 'int' in container_name:
    server_type = 'integration'

# Настройка логирования с ротацией
def setup_logger(log_file, max_size=10*1024*1024):  # 10MB
    logger = logging.getLogger(log_file)
    logger.setLevel(logging.INFO)
    
    handler = RotatingFileHandler(
        log_file,
        maxBytes=max_size,
        backupCount=1,  # сохраняем только один backup файл
        encoding='utf-8'
    )
    handler.setFormatter(logging.Formatter('%(asctime)s [%(levelname)s] %(message)s'))
    
    logger.addHandler(handler)
    return logger

# Основные логи
main_logger = setup_logger(f'/var/log/{server_type}/main.log')

# Логи обработки документов
doc_logger = setup_logger(f'/var/log/{server_type}/documents.log')

# Состояние обработки документов (для эмуляции workflow)
document_stages = {
    'web': ['received', 'preprocessed', 'sent_to_app'],
    'app': ['received_from_web', 'processed', 'sent_to_int'],
    'integration': ['received_from_app', 'external_processed', 'sent_back_to_app'],
    # Обратный путь
    'app_return': ['received_from_int', 'postprocessed', 'sent_back_to_web'],
    'web_return': ['received_from_app', 'finalized', 'completed']
}

def generate_document_flow(guid):
    """Генерация полного workflow для документа"""
    if server_type == 'web':
        stages = document_stages['web']
    elif server_type == 'app':
        # 50/50 - либо получаем от web, либо от int (обратный путь)
        if random.random() > 0.5:
            stages = document_stages['app']
        else:
            stages = document_stages['app_return']
    elif server_type == 'integration':
        stages = document_stages['integration']
    
    for stage in stages:
        log_message = f"DOCUMENT {guid} - {stage.upper()}"
        doc_logger.info(log_message)
        
        # Добавляем дополнительную информацию
        if 'processed' in stage:
            details = [
                f"DOCUMENT {guid} - Processing step 1 completed",
                f"DOCUMENT {guid} - Validation passed",
                f"DOCUMENT {guid} - Metadata extracted"
            ]
            for detail in details:
                doc_logger.info(detail)
        
        time.sleep(random.uniform(0.1, 0.5))  # Небольшая задержка между этапами

def generate_regular_logs():
    """Генерация обычных логов сервера"""
    levels = ['INFO', 'WARNING', 'ERROR', 'DEBUG']
    messages = {
        'web': [
            "User request received",
            "Authentication successful",
            "Cache hit",
            "API response time 245ms"
        ],
        'app': [
            "Processing request ID 12345",
            "Database query executed",
            "Cache updated",
            "Task queue size: 15"
        ],
        'integration': [
            "External service response 200 OK",
            "Data transformation completed",
            "Queue processing started",
            "SSL handshake successful"
        ]
    }
    
    message = random.choice(messages[server_type])
    main_logger.info(message)

def write_to_dynamic_dir():
    """Запись в динамические директории"""
    now = datetime.now()
    dynamic_dir = f"/var/log/{server_type}/hourly/{now.strftime('%Y-%m-%d_%H')}"
    os.makedirs(dynamic_dir, exist_ok=True)
    
    log_file = os.path.join(dynamic_dir, f"{server_type}_hourly.log")
    with open(log_file, 'a') as f:
        f.write(f"{datetime.now().isoformat()} - Dynamic log entry\n")

def cleanup_old_logs():
    """Очистка старых логов в динамических директориях"""
    log_dir = f"/var/log/{server_type}/hourly"
    if os.path.exists(log_dir):
        now = time.time()
        for dirname in os.listdir(log_dir):
            dirpath = os.path.join(log_dir, dirname)
            # Удаляем директории старше 24 часов
            if os.path.isdir(dirpath) and (now - os.path.getmtime(dirpath)) > 86400:
                for f in os.listdir(dirpath):
                    os.remove(os.path.join(dirpath, f))
                os.rmdir(dirpath)

def main():
    # Создаем необходимые директории
    os.makedirs(f"/var/log/{server_type}/hourly", exist_ok=True)
    
    while True:
        # Регулярные логи сервера
        generate_regular_logs()
        
        # 30% chance начать обработку нового документа
        if random.random() < 0.3:
            doc_guid = str(uuid.uuid4())
            generate_document_flow(doc_guid)
        
        # Каждый час пишем в динамическую директорию
        if datetime.now().minute == 0:
            write_to_dynamic_dir()
            cleanup_old_logs()
        
        sleep_time = random.randint(5, 20)
        time.sleep(sleep_time)

if __name__ == "__main__":
    main()
