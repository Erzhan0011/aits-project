# PowerShell script to start Flutter frontend
# Usage: .\start_frontend.ps1

$ErrorActionPreference = "Stop"

# Set console encoding
[Console]::OutputEncoding = [System.Text.Encoding]::UTF8

Write-Host "========================================" -ForegroundColor Cyan
Write-Host "  Запуск Frontend (Flutter)" -ForegroundColor Cyan
Write-Host "========================================" -ForegroundColor Cyan
Write-Host ""

# Change to flutter_app directory
$scriptPath = Split-Path -Parent $MyInvocation.MyCommand.Path
$flutterAppPath = Join-Path $scriptPath "flutter_app"
Set-Location $flutterAppPath

# Find Flutter
$flutterPaths = @(
    "C:\flutter\bin\flutter.bat",
    "D:\flutter\bin\flutter.bat",
    "$env:LOCALAPPDATA\flutter\bin\flutter.bat",
    "$env:USERPROFILE\flutter\bin\flutter.bat",
    "C:\src\flutter\bin\flutter.bat"
)

$flutterCmd = $null
$flutterPath = $null

foreach ($path in $flutterPaths) {
    if (Test-Path $path) {
        $flutterCmd = $path
        $flutterPath = Split-Path -Parent (Split-Path -Parent $path)
        Write-Host "[INFO] Найден Flutter: $flutterPath" -ForegroundColor Green
        break
    }
}

# If Flutter not found, ask user
if (-not $flutterCmd) {
    Write-Host "[ОШИБКА] Flutter не найден в стандартных местах!" -ForegroundColor Red
    Write-Host ""
    $userPath = Read-Host "Введите путь к Flutter SDK (например C:\flutter)"
    $flutterCmd = Join-Path $userPath "bin\flutter.bat"
    
    if (-not (Test-Path $flutterCmd)) {
        Write-Host "[ОШИБКА] Flutter не найден по указанному пути!" -ForegroundColor Red
        Write-Host "Проверьте, что путь правильный и Flutter установлен." -ForegroundColor Yellow
        Read-Host "Нажмите Enter для выхода"
        exit 1
    }
    $flutterPath = $userPath
}

# Add Flutter to PATH for current session
$env:PATH = "$flutterPath\bin;$env:PATH"

# Create missing directories
if (-not (Test-Path "assets")) {
    New-Item -ItemType Directory -Path "assets" | Out-Null
}
if (-not (Test-Path "assets\images")) {
    New-Item -ItemType Directory -Path "assets\images" | Out-Null
}

# Create .env file if it doesn't exist
if (-not (Test-Path ".env")) {
    "API_BASE_URL=http://localhost:8000" | Out-File -FilePath ".env" -Encoding UTF8
    Write-Host "[INFO] Создан файл .env" -ForegroundColor Green
}

# Add web support if needed
if (-not (Test-Path "web")) {
    Write-Host "[INFO] Добавляю веб-поддержку..." -ForegroundColor Yellow
    & $flutterCmd create . --platforms=web 2>&1 | Out-Null
}

# Install dependencies if needed
if (-not (Test-Path "pubspec.lock")) {
    Write-Host "[INFO] Устанавливаю зависимости..." -ForegroundColor Yellow
    & $flutterCmd pub get
    if ($LASTEXITCODE -ne 0) {
        Write-Host "[ОШИБКА] Не удалось установить зависимости!" -ForegroundColor Red
        Read-Host "Нажмите Enter для выхода"
        exit 1
    }
}

Write-Host ""
Write-Host "========================================" -ForegroundColor Cyan
Write-Host "  Запуск приложения в Edge..." -ForegroundColor Cyan
Write-Host "========================================" -ForegroundColor Cyan
Write-Host ""
Write-Host "Приложение откроется на http://localhost:8080" -ForegroundColor Green
Write-Host "Для остановки нажмите Ctrl+C" -ForegroundColor Yellow
Write-Host ""

# Run Flutter app
& $flutterCmd run -d edge --web-port=8080

Read-Host "`nНажмите Enter для выхода"

