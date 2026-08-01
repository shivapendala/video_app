#!/bin/bash
# ElevateIQ Video Platform - Hostinger VPS Deployment Script
set -e

echo "================================================"
echo "  ElevateIQ Video Platform - VPS Deployment"
echo "================================================"

# 1. System Update & Dependencies
echo "[1/6] Installing dependencies..."
apt-get update -qq
apt-get install -y -qq git curl nginx

# 2. Install Docker if not present
echo "[2/6] Setting up Docker..."
if ! command -v docker &>/dev/null; then
    curl -fsSL https://get.docker.com | sh
    systemctl enable docker
    systemctl start docker
    echo "Docker installed!"
else
    echo "Docker already installed: $(docker --version)"
fi

# Install docker compose plugin
if ! docker compose version &>/dev/null 2>&1; then
    apt-get install -y -qq docker-compose-plugin
fi
echo "Docker Compose: $(docker compose version)"

# 3. Clone / Update project from GitHub
echo "[3/6] Cloning project from GitHub..."
mkdir -p /var/www
if [ -d /var/www/video_app ]; then
    echo "Repo exists, pulling latest..."
    cd /var/www/video_app && git pull origin main
else
    git clone https://github.com/shivapendala/video_app.git /var/www/video_app
fi

# 4. Create production .env
echo "[4/6] Creating production environment..."
cat > /var/www/video_app/backend/.env << 'ENVEOF'
NODE_ENV=production
PORT=5000
DB_HOST=db
DB_PORT=5432
DB_NAME=elevateiq_db
DB_USER=elevateiq_user
DB_PASSWORD=ElevateiqDB@2026
JWT_SECRET=elevateiq_jwt_secret_production_2026
JWT_EXPIRES_IN=7d
ENVEOF
echo "Backend .env created"

# 5. Start Docker containers
echo "[5/6] Starting containers..."
cd /var/www/video_app
docker compose up --build -d
echo "Waiting for containers to be healthy..."
sleep 15
docker ps --format "table {{.Names}}\t{{.Status}}\t{{.Ports}}"

# 6. Configure Nginx subpath (safe - won't break main site)
echo "[6/6] Configuring Nginx subpath routing..."
cat > /etc/nginx/snippets/video-platform.conf << 'NGINXEOF'
    # ElevateIQ Video Platform - Subpath Routes
    location /video-platform-api/ {
        proxy_pass http://127.0.0.1:5000/;
        proxy_http_version 1.1;
        proxy_set_header Host $host;
        proxy_set_header X-Real-IP $remote_addr;
        proxy_set_header X-Forwarded-For $proxy_add_x_forwarded_for;
        proxy_set_header X-Forwarded-Proto $scheme;
    }

    location /video-platform/ {
        proxy_pass http://127.0.0.1:8081/;
        proxy_http_version 1.1;
        proxy_set_header Host $host;
        proxy_set_header X-Real-IP $remote_addr;
    }
NGINXEOF

# Find the active Nginx server block and inject the include
NGINX_CONF=""
for f in /etc/nginx/sites-enabled/*; do
    if grep -q "server_name" "$f" 2>/dev/null; then
        NGINX_CONF="$f"
        break
    fi
done

if [ -n "$NGINX_CONF" ]; then
    if ! grep -q "video-platform" "$NGINX_CONF"; then
        # Insert include after the first server_name line
        sed -i '/server_name/a\    include /etc/nginx/snippets/video-platform.conf;' "$NGINX_CONF"
        echo "Injected video-platform routes into: $NGINX_CONF"
    else
        echo "Video-platform routes already configured in: $NGINX_CONF"
    fi
else
    echo "WARNING: No active Nginx config found. Please add manually:"
    echo "  include /etc/nginx/snippets/video-platform.conf;"
fi

nginx -t && systemctl reload nginx
echo "Nginx reloaded OK"

echo ""
echo "================================================"
echo "  DEPLOYMENT COMPLETE!"
echo "================================================"
echo "  Frontend : https://elevateiq-softtech.com/video-platform/"
echo "  API      : https://elevateiq-softtech.com/video-platform-api/api/v1/"
echo "================================================"
