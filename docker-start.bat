@echo off
title Video Platform • 1-Click Docker Launcher
color 0A

echo ========================================================
echo   🚀 Video Data Collection Platform - 1-Click Docker
echo ========================================================
echo.
echo 📦 Building and starting Docker containers (Database, Backend, Frontend)...
echo.

docker-compose up --build -d

if %errorlevel% neq 0 (
    echo.
    echo ❌ Docker Compose failed to start. Please check if Docker Desktop is running.
    pause
    exit /b %errorlevel%
)

echo.
echo ========================================================
echo   ✅ All Services Launched Successfully!
echo ========================================================
echo.
echo 📱 Web App Portal:  http://localhost:8081
echo ⚡ REST API Server: http://localhost:5000/api/v1
echo 🗄️ PostgreSQL DB:  localhost:5432
echo.
echo Opening Web Portal in your browser...
start http://localhost:8081
echo.
echo Press any key to stop containers when finished...
pause >nul

echo 🛑 Stopping Docker containers...
docker-compose down
echo Done!
