# deploy_to_hostinger.ps1 - One-shot Hostinger VPS deployment script

$VPS_IP = "195.35.21.139"
$VPS_USER = "root"
$VPS_PASS = "Elevateiq@95153"
$PUBKEY = Get-Content "$env:USERPROFILE\.ssh\hostinger_vps.pub"
$KEY_FILE = "$env:USERPROFILE\.ssh\hostinger_vps"

Write-Host "==> Installing Posh-SSH module..." -ForegroundColor Cyan
Install-Module -Name Posh-SSH -Force -Scope CurrentUser -AllowClobber 2>&1 | Out-Null
Import-Module Posh-SSH

Write-Host "==> Connecting to VPS $VPS_IP..." -ForegroundColor Cyan
$SecurePass = ConvertTo-SecureString $VPS_PASS -AsPlainText -Force
$Credential = New-Object System.Management.Automation.PSCredential($VPS_USER, $SecurePass)

$session = New-SSHSession -ComputerName $VPS_IP -Credential $Credential -AcceptKey -Force
if (-not $session) {
    Write-Error "SSH connection failed!"
    exit 1
}
Write-Host "==> Connected!" -ForegroundColor Green

function Run($cmd) {
    $result = Invoke-SSHCommand -SessionId $session.SessionId -Command $cmd -TimeOut 300
    if ($result.Output) { Write-Host $result.Output -ForegroundColor White }
    if ($result.Error)  { Write-Host $result.Error  -ForegroundColor Yellow }
    return $result
}

# 1. Install SSH key for passwordless future access
Write-Host "`n==> [1/7] Installing SSH key..." -ForegroundColor Cyan
Run "mkdir -p ~/.ssh && chmod 700 ~/.ssh"
Run "echo '$PUBKEY' >> ~/.ssh/authorized_keys && chmod 600 ~/.ssh/authorized_keys"

# 2. Check existing server state
Write-Host "`n==> [2/7] Checking existing server state..." -ForegroundColor Cyan
Run "cat /etc/os-release | head -3"
Run "nginx -v 2>&1 || echo 'Nginx not installed'"
Run "docker --version 2>&1 || echo 'Docker not installed'"
Run "ls /etc/nginx/sites-enabled/ 2>/dev/null"
Run "ss -tlnp | grep -E ':80|:443|:3000|:5000|:8081'"

# 3. Install Docker if not present
Write-Host "`n==> [3/7] Installing Docker & Docker Compose..." -ForegroundColor Cyan
Run "if ! command -v docker &>/dev/null; then curl -fsSL https://get.docker.com | sh && systemctl enable docker && systemctl start docker; else echo 'Docker already installed'; fi"
Run "if ! docker compose version &>/dev/null 2>&1; then apt-get install -y docker-compose-plugin; else echo 'Docker Compose already available'; fi"

# 4. Clone project from GitHub
Write-Host "`n==> [4/7] Cloning project from GitHub..." -ForegroundColor Cyan
Run "mkdir -p /var/www && cd /var/www && if [ -d video_app ]; then cd video_app && git pull origin main; else git clone https://github.com/shivapendala/video_app.git; fi"

# 5. Create .env file for backend
Write-Host "`n==> [5/7] Creating production .env..." -ForegroundColor Cyan
$envContent = @'
NODE_ENV=production
PORT=5000
DB_HOST=db
DB_PORT=5432
DB_NAME=elevateiq_db
DB_USER=elevateiq_user
DB_PASSWORD=ElevateiqDB@2026
JWT_SECRET=elevateiq_jwt_secret_production_2026
JWT_EXPIRES_IN=7d
'@
Run "cat > /var/www/video_app/backend/.env << 'ENVEOF'`n$envContent`nENVEOF"

# 6. Start containers
Write-Host "`n==> [6/7] Starting Docker containers..." -ForegroundColor Cyan
Run "cd /var/www/video_app && docker compose up --build -d 2>&1 | tail -20"
Run "sleep 15 && docker ps --format 'table {{.Names}}\t{{.Status}}\t{{.Ports}}'"

# 7. Configure Nginx subpath routing
Write-Host "`n==> [7/7] Configuring Nginx subpath routing..." -ForegroundColor Cyan
$nginxConf = @'
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
'@
Run "echo '$nginxConf' > /etc/nginx/snippets/video-platform.conf"
Run "grep -q 'video-platform' /etc/nginx/sites-enabled/* 2>/dev/null || sed -i '/server_name/a\    include /etc/nginx/snippets/video-platform.conf;' /etc/nginx/sites-enabled/default 2>/dev/null || echo 'Manual Nginx include needed'"
Run "nginx -t 2>&1 && systemctl reload nginx && echo 'Nginx reloaded OK'"

Write-Host "`n========================================" -ForegroundColor Green
Write-Host "  DEPLOYMENT COMPLETE!" -ForegroundColor Green
Write-Host "========================================" -ForegroundColor Green
Write-Host "  Frontend : https://elevateiq-softtech.com/video-platform/" -ForegroundColor Cyan
Write-Host "  API      : https://elevateiq-softtech.com/video-platform-api/api/v1/" -ForegroundColor Cyan
Write-Host "========================================" -ForegroundColor Green

Remove-SSHSession -SessionId $session.SessionId
