<#
.SYNOPSIS
    Deployment script for log emulation system
#>

# Colors for output
$RED = [ConsoleColor]::Red
$YELLOW = [ConsoleColor]::Yellow
$GREEN = [ConsoleColor]::Green

# Устанавливаем кодировку консоли в UTF-8 для корректного отображения Unicode-символов
[Console]::OutputEncoding = [System.Text.Encoding]::UTF8

function Write-Status {
    param (
        [string]$Message,
        [string]$Status
    )
    $checkmark = [char]0x2713  # Unicode символ галочки
    $cross = [char]0x2717      # Unicode символ крестика
    $statusSymbol = if ($Status -eq "success") { $checkmark } else { $cross }
    Write-Host "[$statusSymbol] $Message"
}

# Cleanup
Write-Status -Message "Cleaning up previous deployment..." -Status "info"
docker-compose down -v

# Create directory structure
Write-Status -Message "Creating directory structure..." -Status "info"
New-Item -ItemType Directory -Force -Path "shared/web" | Out-Null
New-Item -ItemType Directory -Force -Path "shared/app" | Out-Null
New-Item -ItemType Directory -Force -Path "shared/int" | Out-Null

# Copy required files
Write-Status -Message "Copying files..." -Status "info"
Copy-Item -Path "logsrvtempl.log_generator.py" -Destination "shared/web/log_generator.py" -Force
Copy-Item -Path "logsrvtempl.log_generator.py" -Destination "shared/app/log_generator.py" -Force
Copy-Item -Path "logsrvtempl.log_generator.py" -Destination "shared/int/log_generator.py" -Force
Copy-Item -Path "logsrvtempl.dockerfile" -Destination "shared/web/Dockerfile" -Force
Copy-Item -Path "logsrvtempl.dockerfile" -Destination "shared/app/Dockerfile" -Force
Copy-Item -Path "logsrvtempl.dockerfile" -Destination "shared/int/Dockerfile" -Force
Copy-Item -Path "filebeat-8.13.4-linux-x86_64.tar.gz" -Destination "shared/web/" -Force
Copy-Item -Path "filebeat-8.13.4-linux-x86_64.tar.gz" -Destination "shared/app/" -Force
Copy-Item -Path "filebeat-8.13.4-linux-x86_64.tar.gz" -Destination "shared/int/" -Force
Copy-Item -Path "filebeat.yml" -Destination "shared/web/" -Force
Copy-Item -Path "filebeat.yml" -Destination "shared/app/" -Force
Copy-Item -Path "filebeat.yml" -Destination "shared/int/" -Force

# Start services
Write-Status -Message "Starting containers..." -Status "info"
docker-compose up -d

# Check container health
Write-Status -Message "Checking container status..." -Status "info"
$maxAttempts = 12
$attempt = 0
$allRunning = $false

while (-not $allRunning -and $attempt -lt $maxAttempts) {
    $attempt++
    $psOutput = docker-compose ps
    $allRunning = $true
    
    # Проверяем каждый контейнер по реальным именам
    foreach ($line in $psOutput -split "`n") {
        if ($line -match "app1|app2|web1|web2|int1|int2|minio|elasticsearch|kibana") {
            if ($line -match "Exit|unhealthy|Restarting|Dead") {
                $allRunning = $false
                Write-Status -Message "Container $($line.Split()[0]) is not running properly" -Status "error"
                break
            }
        }
    }
    
    if (-not $allRunning) {
        Write-Status -Message "Waiting for containers to be ready... (Attempt $attempt of $maxAttempts)" -Status "info"
        Start-Sleep -Seconds 5
    }
}

if (-not $allRunning) {
    Write-Status -Message "Some containers failed to start properly" -Status "error"
    exit 1
}

Write-Status -Message "All containers running" -Status "success"

# Initialize MinIO
Write-Status -Message "Initializing MinIO buckets..." -Status "info"
$maxAttempts = 12
$attempt = 0
$minioReady = $false

while (-not $minioReady -and $attempt -lt $maxAttempts) {
    $attempt++
    try {
        $response = Invoke-WebRequest -Uri "http://localhost:9000/minio/health/live" -UseBasicParsing
        if ($response.StatusCode -eq 200) {
            $minioReady = $true
        }
    }
    catch {
        Write-Status -Message "Waiting for MinIO to be ready... (Attempt $attempt of $maxAttempts)" -Status "info"
        Start-Sleep -Seconds 5
    }
}

if (-not $minioReady) {
    Write-Status -Message "MinIO failed to start properly" -Status "error"
    exit 1
}

# Создание бакетов в MinIO
Write-Status -Message "Creating MinIO buckets..." -Status "info"
$buckets = @("app-simple", "app-blog", "web-simple", "web-blog", "int-simple", "int-blog")
foreach ($bucket in $buckets) {
    try {
        docker exec minio /usr/bin/mc alias set local http://localhost:9000 admin password123 --insecure
        docker exec minio /usr/bin/mc mb local/$bucket --insecure
        Write-Status -Message "Created bucket: $bucket" -Status "success"
    }
    catch {
        Write-Status -Message "Failed to create bucket: $bucket" -Status "error"
    }
}

# Initialize Elasticsearch indices
Write-Status -Message "Creating Elasticsearch indices..." -Status "info"
$maxAttempts = 12
$attempt = 0
$esReady = $false

while (-not $esReady -and $attempt -lt $maxAttempts) {
    $attempt++
    try {
        $response = Invoke-WebRequest -Uri "http://localhost:9200" -UseBasicParsing
        if ($response.StatusCode -eq 200) {
            $esReady = $true
        }
    }
    catch {
        Write-Status -Message "Waiting for Elasticsearch to be ready... (Attempt $attempt of $maxAttempts)" -Status "info"
        Start-Sleep -Seconds 5
    }
}

if (-not $esReady) {
    Write-Status -Message "Elasticsearch failed to start properly" -Status "error"
    exit 1
}

# Создание индексов
$indices = @("app-simple", "app-blog", "web-simple", "web-blog", "int-simple", "int-blog")
foreach ($index in $indices) {
    try {
        $response = Invoke-WebRequest -Uri "http://localhost:9200/$index" -Method PUT -UseBasicParsing
        Write-Status -Message "Created index: $index" -Status "success"
    }
    catch {
        if ($_.Exception.Response.StatusCode -eq 400) {
            Write-Status -Message "Index $index already exists" -Status "info"
        }
        else {
            Write-Status -Message "Failed to create index $index" -Status "error"
        }
    }
}

Write-Status -Message "Deployment successful!" -Status "success"
Write-Host "`nAccess:"
Write-Host "MinIO Console: http://localhost:9001 (admin/password123)"
Write-Host "Kibana: http://localhost:5601"
Write-Host "`nTo check logs:"
Write-Host "docker exec -it web1 tail -f /var/log/shared/web/main.log"