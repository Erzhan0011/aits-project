@echo off
chcp 65001 >nul
cd /d "%~dp0"

echo ========================================
echo   Запуск Frontend (Flutter Web)
echo ========================================
echo.

REM Проверка Flutter в PATH
where flutter >nul 2>&1
if %ERRORLEVEL% NEQ 0 (
    echo [ОШИБКА] Flutter не найден в PATH!
    echo.
    echo Пожалуйста:
    echo 1. Убедитесь что Flutter установлен
    echo 2. Добавьте Flutter в PATH
    echo    Или укажите полный путь к flutter.bat ниже
    echo.
    set /p FLUTTER_CMD="Введите полный путь к flutter.bat (например C:\flutter\bin\flutter.bat): "
    if not exist "%FLUTTER_CMD%" (
        echo [ОШИБКА] Файл не найден!
        pause
        exit /b 1
    )
) else (
    set FLUTTER_CMD=flutter
)

echo [INFO] Используется: %FLUTTER_CMD%
echo.

REM Установка зависимостей
echo [INFO] Устанавливаю зависимости...
call "%FLUTTER_CMD%" pub get
if %ERRORLEVEL% NEQ 0 (
    echo [ОШИБКА] Не удалось установить зависимости!
    pause
    exit /b 1
)

echo.
echo ========================================
echo   Запуск приложения...
echo ========================================
echo.
echo Приложение откроется на http://localhost:8080
echo Для остановки нажмите Ctrl+C
echo.

call "%FLUTTER_CMD%" run -d chrome --web-port=8080

pause



