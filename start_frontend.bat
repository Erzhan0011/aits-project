@echo off
chcp 65001 >nul
cd /d "%~dp0flutter_app"

echo ========================================
echo   Запуск Frontend (Flutter)
echo ========================================
echo.

REM Поиск Flutter
set FLUTTER_CMD=
set FLUTTER_FOUND=0

REM Проверка стандартных путей
if exist "C:\flutter\bin\flutter.bat" (
    set FLUTTER_CMD=C:\flutter\bin\flutter.bat
    set FLUTTER_FOUND=1
    set FLUTTER_PATH=C:\flutter
) else if exist "D:\flutter\bin\flutter.bat" (
    set FLUTTER_CMD=D:\flutter\bin\flutter.bat
    set FLUTTER_FOUND=1
    set FLUTTER_PATH=D:\flutter
) else if exist "%LOCALAPPDATA%\flutter\bin\flutter.bat" (
    set FLUTTER_CMD=%LOCALAPPDATA%\flutter\bin\flutter.bat
    set FLUTTER_FOUND=1
    set FLUTTER_PATH=%LOCALAPPDATA%\flutter
) else if exist "%USERPROFILE%\flutter\bin\flutter.bat" (
    set FLUTTER_CMD=%USERPROFILE%\flutter\bin\flutter.bat
    set FLUTTER_FOUND=1
    set FLUTTER_PATH=%USERPROFILE%\flutter
) else if exist "C:\src\flutter\bin\flutter.bat" (
    set FLUTTER_CMD=C:\src\flutter\bin\flutter.bat
    set FLUTTER_FOUND=1
    set FLUTTER_PATH=C:\src\flutter
)

REM Если Flutter не найден, запрашиваем путь
if %FLUTTER_FOUND%==0 (
    echo [ОШИБКА] Flutter не найден в стандартных местах!
    echo.
    echo Укажите путь к Flutter SDK:
    set /p FLUTTER_PATH="Введите путь (например C:\flutter): "
    if not exist "%FLUTTER_PATH%\bin\flutter.bat" (
        echo [ОШИБКА] Flutter не найден по указанному пути!
        echo Проверьте, что путь правильный и Flutter установлен.
        pause
        exit /b 1
    )
    set FLUTTER_CMD=%FLUTTER_PATH%\bin\flutter.bat
)

REM Добавляем Flutter в PATH для текущей сессии
set "PATH=%FLUTTER_PATH%\bin;%PATH%"
echo [INFO] Используется Flutter: %FLUTTER_PATH%

REM Создание недостающих файлов
if not exist "assets" mkdir assets
if not exist "assets\images" mkdir assets\images
if not exist ".env" (
    echo API_BASE_URL=http://localhost:8000 > .env
)

REM Добавление веб-поддержки если нужно
if not exist "web" (
    echo [INFO] Добавляю веб-поддержку...
    "%FLUTTER_CMD%" create . --platforms=web >nul 2>&1
)

REM Установка зависимостей
if not exist "pubspec.lock" (
    echo [INFO] Устанавливаю зависимости...
    "%FLUTTER_CMD%" pub get
)

echo.
echo ========================================
echo   Запуск приложения в Edge...
echo ========================================
echo.
echo Приложение откроется на http://localhost:8080
echo Для остановки нажмите Ctrl+C
echo.

"%FLUTTER_CMD%" run -d edge --web-port=8080

pause



