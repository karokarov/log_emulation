import os
import random
import time
from datetime import datetime
import uuid
import logging
from logging.handlers import RotatingFileHandler
import json

# Server configuration
server_type = os.environ.get('SERVER_TYPE', 'web')
container_name = os.environ.get('HOSTNAME', 'unknown')

# Logging setup
def setup_logger(log_file, max_size=10*1024*1024):
    os.makedirs(os.path.dirname(log_file), exist_ok=True)
    
    logger = logging.getLogger(log_file)
    logger.setLevel(logging.INFO)
    
    handler = RotatingFileHandler(
        log_file,
        maxBytes=max_size,
        backupCount=1,
        encoding='utf-8'
    )
    handler.setFormatter(logging.Formatter('%(asctime)s [%(levelname)s] %(message)s'))
    logger.addHandler(handler)
    return logger

main_logger = setup_logger(f'/var/log/shared/{server_type}/main.log')
doc_logger = setup_logger(f'/var/log/shared/{server_type}/documents.log')

def get_blog_directory():
    now = datetime.now()
    base_dir = f"/var/log/shared/{server_type}/blog"
    date_dir = os.path.join(base_dir, str(now.day))
    hour_dir = os.path.join(date_dir, str(now.hour))
    os.makedirs(hour_dir, exist_ok=True)
    return hour_dir

def generate_blog_log():
    log_dir = get_blog_directory()
    log_file = os.path.join(log_dir, f"{uuid.uuid4()}.txt")
    
    log_data = {
        "uuid": str(uuid.uuid4()),
        "server": server_type,
        "container": container_name,
        "timestamp": datetime.now().isoformat(),
        "status": "SUCCESS" if random.random() > 0.2 else "FAILED",
        "processing_time": round(random.uniform(0.1, 2.5), 2),
        "data": random.getrandbits(128)
    }
    
    with open(log_file, 'w') as f:
        json.dump(log_data, f, indent=2)
    
    main_logger.info(f"Generated blog log: {log_file}")

def generate_document_flow(guid):
    stages = {
        'web': ['received', 'preprocessed', 'sent_to_app'],
        'app': ['received_from_web', 'processed', 'sent_to_int'],
        'integration': ['received_from_app', 'external_processed', 'sent_back_to_app']
    }.get(server_type, [])
    
    for stage in stages:
        doc_logger.info(f"DOCUMENT {guid} - {stage.upper()}")
        time.sleep(random.uniform(0.1, 0.5))

def generate_regular_logs():
    messages = {
        'web': ["User request received", "Authentication successful"],
        'app': ["Database query executed", "Cache updated"],
        'integration': ["External service response", "Data transformation completed"]
    }
    main_logger.info(random.choice(messages[server_type]))

def main():
    while True:
        generate_regular_logs()
        if random.random() < 0.3:
            generate_document_flow(str(uuid.uuid4()))
        if random.random() < 0.2:
            generate_blog_log()
        time.sleep(1)

if __name__ == "__main__":
    main()