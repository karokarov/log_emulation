FROM python:3.9-alpine

ARG SERVER_TYPE=default
ENV SERVER_TYPE=${SERVER_TYPE}

WORKDIR /app

# Установка зависимостей
RUN apk add --no-cache bash curl

# Копирование и распаковка Filebeat
COPY filebeat-8.13.4-linux-x86_64.tar.gz .
RUN tar -xzf filebeat-8.13.4-linux-x86_64.tar.gz -C /usr/share/ && \
    mv /usr/share/filebeat-8.13.4-linux-x86_64 /usr/share/filebeat && \
    ln -s /usr/share/filebeat/filebeat /usr/local/bin/filebeat && \
    chmod +x /usr/share/filebeat/filebeat && \
    rm filebeat-8.13.4-linux-x86_64.tar.gz

# Копирование файлов приложения
COPY log_generator.py .
COPY filebeat.yml /usr/share/filebeat/filebeat.yml

# Настройка прав
RUN mkdir -p /var/log/shared && \
    chown -R root:root /usr/share/filebeat && \
    chmod go-w /usr/share/filebeat/filebeat.yml

CMD filebeat -c /usr/share/filebeat/filebeat.yml & python /app/log_generator.py