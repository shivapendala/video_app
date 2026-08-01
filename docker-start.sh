#!/usr/bin/env bash

echo "========================================================"
echo "  🚀 Video Data Collection Platform - 1-Click Docker"
echo "========================================================"
echo ""
echo "📦 Building and starting Docker containers..."
echo ""

docker compose up --build -d || docker-compose up --build -d

if [ $? -eq 0 ]; then
  echo ""
  echo "========================================================"
  echo "  ✅ All Services Launched Successfully!"
  echo "========================================================"
  echo ""
  echo "📱 Web App Portal:  http://localhost:8081"
  echo "⚡ REST API Server: http://localhost:5000/api/v1"
  echo "🗄️ PostgreSQL DB:  localhost:5432"
  echo ""
  echo "Opening http://localhost:8081..."
  if command -v open &> /dev/null; then
    open http://localhost:8081
  elif command -v xdg-open &> /dev/null; then
    xdg-open http://localhost:8081
  fi
else
  echo "❌ Docker Compose failed. Please ensure Docker engine is running."
fi
