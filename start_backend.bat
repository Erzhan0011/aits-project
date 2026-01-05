@echo off
chcp 65001 >nul
cd /d "%~dp0backend"

echo ========================================
echo   Запуск Backend (FastAPI)
echo ========================================
echo.

REM Проверка Python
python --version >nul 2>&1
if errorlevel 1 (
    echo [ОШИБКА] Python не найден!
    pause
    exit /b 1
)

REM Проверка .env
if not exist .env (
    echo [INFO] Создаю файл .env...
    (
        echo SECRET_KEY=your-secret-key-here-change-in-production-12345
        echo ALGORITHM=HS256
        echo ACCESS_TOKEN_EXPIRE_MINUTES=30
        echo DATABASE_URL=sqlite:///./airline.db
    ) > .env
)

REM Проверка БД
if not exist airline.db (
    echo [INFO] Инициализация базы данных...
    python init_db.py
)

echo.
echo ========================================
echo   Запуск сервера...
echo ========================================
echo.
echo API: http://localhost:8000
echo Swagger: http://localhost:8000/docs
echo.
echo Для остановки нажмите Ctrl+C
echo.

python -m uvicorn main:app --reload --host 0.0.0.0 --port 8000

pause
