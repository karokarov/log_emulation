FROM minio/minio

# Установка mc без использования пакетных менеджеров
RUN curl -o /usr/bin/mc https://dl.min.io/client/mc/release/linux-amd64/mc && \
    chmod +x /usr/bin/mc

# Запускаем MinIO
CMD ["server", "/data", "--console-address", ":9001"]