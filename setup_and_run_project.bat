@echo off
setlocal

echo ==========================================
echo    Airline Project Setup and Run Script
echo ==========================================

REM --- Backend Setup ---
echo.
echo [1/4] Setting up Backend...
cd backend

IF NOT EXIST ".venv" (
    echo Creating virtual environment (.venv)...
    python -m venv .venv
) ELSE (
    echo Virtual environment found.
)

echo Activating virtual environment...
call .venv\Scripts\activate.bat

echo Installing dependencies...
pip install -r requirements.txt

REM --- Start Backend ---
echo.
echo [2/4] Starting Backend Server...
REM Start in a new window so this script can continue
start "Airline Backend" cmd /k "title Airline Backend && echo Server running at http://localhost:8000 && python main.py"

REM --- Frontend Setup ---
echo.
echo [3/4] Setting up Frontend...
cd ..\flutter_app

echo Getting Flutter packages...
call flutter pub get

REM --- Start Frontend ---
echo.
echo [4/4] Starting Flutter App...
echo Launching Chrome...
call flutter run -d chrome

echo.
echo ==========================================
echo    Both services should be running!
echo    Backend: http://localhost:8000/docs
echo    Frontend: Chrome window
echo ==========================================
pause
