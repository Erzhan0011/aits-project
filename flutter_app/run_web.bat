@echo off
title Zhan Airline Launcher
cls
echo ==========================================
echo      ZHAN AIRLINE - WEB LAUNCHER
echo ==========================================
echo.
echo Select Browser:
echo [1] Google Chrome
echo [2] Microsoft Edge
echo.
set /p browser="Enter choice (1 or 2): "

if "%browser%"=="1" (
    echo.
    echo Starting in Google Chrome...
    call flutter run -d chrome
) else if "%browser%"=="2" (
    echo.
    echo Starting in Microsoft Edge...
    call flutter run -d edge
) else (
    echo.
    echo Invalid choice! Please enter 1 or 2.
    pause
)
