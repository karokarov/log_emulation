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

# Состояние обработки документов
document_stages = {
    'web': ['received', 'preprocessed', 'sent_to_app'],
    'app': ['received_from_web', 'processed', 'sent_to_int'],
    'integration': ['received_from_app', 'external_processed', 'sent_back_to_app'],
    'app_return': ['received_from_int', 'postprocessed', 'sent_back_to_web'],
    'web_return': ['received_from_app', 'finalized', 'completed']
}

def get_blog_directory():
    """Создает структуру директорий для сложных логов blog/[day]/[hour]"""
    now = datetime.now()
    base_dir = f"/var/log/{server_type}/blog"
    date_dir = os.path.join(base_dir, str(now.day))
    hour_dir = os.path.join(date_dir, str(now.hour))
    
    os.makedirs(hour_dir, exist_ok=True)
    return hour_dir

def generate_blog_log():
    """Генерация нового GUID-файла каждые 5-20 секунд"""
    log_dir = get_blog_directory()
    log_file = os.path.join(log_dir, f"{uuid.uuid4()}.txt")
    
    log_content = f"""Document processing details:
- UUID: {uuid.uuid4()}
- Server: {server_type}
- Timestamp: {datetime.now().isoformat()}
- Status: {"SUCCESS" if random.random() > 0.2 else "FAILED"}
- Processing time: {random.uniform(0.1, 2.5):.2f}s
- Additional data: {random.getrandbits(128)}
"""
    
    with open(log_file, 'w') as f:
        f.write(log_content)
    
    main_logger.info(f"Generated new blog log: {log_file}")

def generate_document_flow(guid):
    """Генерация workflow документа"""
    if server_type == 'web':
        stages = document_stages['web']
    elif server_type == 'app':
        stages = document_stages['app'] if random.random() > 0.5 else document_stages['app_return']
    elif server_type == 'integration':
        stages = document_stages['integration']
    
    for stage in stages:
        doc_logger.info(f"DOCUMENT {guid} - {stage.upper()}")
        
        if 'processed' in stage:
            for detail in [
                f"DOCUMENT {guid} - Processing step 1 completed",
                f"DOCUMENT {guid} - Validation passed",
                f"DOCUMENT {guid} - Metadata extracted"
            ]:
                doc_logger.info(detail)
        
        time.sleep(random.uniform(0.1, 0.5))

def generate_regular_logs():
    """Генерация обычных логов"""
    messages = {
        'web': ["User request received", "Authentication successful"],
        'app': ["Database query executed", "Cache updated"],
        'integration': ["External service response", "Data transformation completed"]
    }
    main_logger.info(random.choice(messages[server_type]))

def cleanup_old_logs():
    """Очистка логов старше 7 дней"""
    blog_dir = f"/var/log/{server_type}/blog"
    if os.path.exists(blog_dir):
        cutoff = time.time() - 7 * 86400
        for day in os.listdir(blog_dir):
            day_path = os.path.join(blog_dir, day)
            if os.path.isdir(day_path) and os.path.getmtime(day_path) < cutoff:
                for root, _, files in os.walk(day_path, topdown=False):
                    for file in files:
                        os.remove(os.path.join(root, file))
                    os.rmdir(root)

def main():
    os.makedirs(f"/var/log/{server_type}/blog", exist_ok=True)
    
    last_blog_log = time.time()
    blog_interval = random.uniform(5, 20)
    
    while True:
        current_time = time.time()
        
        # Регулярные логи
        generate_regular_logs()
        
        # Обработка документов (30% chance)
        if random.random() < 0.3:
            generate_document_flow(str(uuid.uuid4()))
        
        # Blog логи каждые 5-20 секунд
        if current_time - last_blog_log >= blog_interval:
            generate_blog_log()
            last_blog_log = current_time
            blog_interval = random.uniform(5, 20)
        
        # Очистка старых логов каждый час
        if datetime.now().minute == 0:
            cleanup_old_logs()
        
        time.sleep(1)  # Основной цикл - 1 секунда

if __name__ == "__main__":
    main()