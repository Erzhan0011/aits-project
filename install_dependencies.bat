@echo off
chcp 65001 >nul
echo Установка зависимостей для проекта Airline...
echo.

echo [1/2] Установка зависимостей для Backend (Python)...
cd backend
python -m pip install -r requirements.txt
if %errorlevel% neq 0 (
    echo ОШИБКА: Не удалось установить зависимости для Backend
    pause
    exit /b 1
)
echo ✓ Backend зависимости установлены
echo.

cd ..
echo [2/2] Установка зависимостей для Frontend (Flutter)...
cd flutter_app
flutter pub get
if %errorlevel% neq 0 (
    echo ОШИБКА: Не удалось установить зависимости для Frontend
    echo Убедитесь, что Flutter установлен и добавлен в PATH
    pause
    exit /b 1
)
echo ✓ Frontend зависимости установлены
echo.

cd ..
echo.
echo ========================================
echo Все зависимости успешно установлены!
echo ========================================
pause



