#!/bin/sh

# Проверяем наличие curl (если образ его включает)
if ! command -v curl >/dev/null 2>&1; then
    echo "Ошибка: curl не найден. Bucket'ы не будут созданы."
    tail -f /dev/null
    exit 0
fi

# Ждем доступности MinIO
echo "Ожидание запуска MinIO..."
while ! curl -s -o /dev/null http://localhost:9000/minio/health/live; do
    sleep 1
done

# Создаем bucket'ы
echo "Настройка MinIO..."
/usr/bin/mc alias set local http://localhost:9000 admin password123 --insecure

for bucket in app-simple app-blog web-simple web-blog int-simple int-blog; do
    echo "Создание bucket: $bucket"
    /usr/bin/mc mb local/$bucket --insecure || true
done

echo "MinIO инициализирован. Bucket'ы:"
/usr/bin/mc ls local --insecure

# Бесконечный цикл
tail -f /dev/null