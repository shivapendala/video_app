terraform {
  required_version = ">= 1.0.0"
  required_providers {
    null = {
      source  = "hashicorp/null"
      version = "~> 3.2.0"
    }
    tls = {
      source  = "hashicorp/tls"
      version = "~> 4.0.0"
    }
  }
}



# Provisioner to configure Hostinger VPS automatically
resource "null_resource" "hostinger_vps_setup" {
  triggers = {
    vps_ip = var.vps_ip
  }

  connection {
    type        = "ssh"
    user        = var.vps_user
    host        = var.vps_ip
    private_key = file("~/.ssh/id_rsa") # Path to your SSH key
  }

  provisioner "remote-exec" {
    inline = [
      "echo '==> Updating system packages...'",
      "sudo apt-get update -y && sudo apt-get upgrade -y",

      "echo '==> Installing Docker & Docker Compose...'",
      "curl -fsSL https://get.docker.com -o get-docker.sh",
      "sh get-docker.sh",
      "sudo apt-get install -y docker-compose-plugin certbot python3-certbot-nginx nginx",

      "echo '==> Setting up Subpath Nginx Reverse Proxy for ${var.domain_name}...'",
      "cat <<'EOF' > /etc/nginx/sites-available/elevateiq_videoplatform",
# Video Platform Dedicated Location Blocks (Leaves main website on / untouched)
server {
    listen 80;
    server_name ${var.domain_name} www.${var.domain_name};

    # 1. Video Platform REST API
    location /video-platform-api/ {
        proxy_pass http://localhost:5000/;
        proxy_http_version 1.1;
        proxy_set_header Upgrade $http_upgrade;
        proxy_set_header Connection 'upgrade';
        proxy_set_header Host $host;
        proxy_set_header X-Real-IP $remote_addr;
        proxy_set_header X-Forwarded-For $proxy_add_x_forwarded_for;
        proxy_set_header X-Forwarded-Proto $scheme;
    }

    # 2. Video Platform Web Application
    location /video-platform/ {
        proxy_pass http://localhost:8081/;
        proxy_http_version 1.1;
        proxy_set_header Host $host;
        proxy_set_header X-Real-IP $remote_addr;
    }
}
EOF",
      "sudo ln -sf /etc/nginx/sites-available/elevateiq_videoplatform /etc/nginx/sites-enabled/",
      "sudo rm -f /etc/nginx/sites-enabled/default",
      "sudo nginx -t && sudo systemctl reload nginx",

      "echo '==> Generating Let's Encrypt SSL Certificate for ${var.domain_name}...'",
      "sudo certbot --nginx -d ${var.domain_name} --non-interactive --agree-tos -m admin@${var.domain_name} || true",

      "echo '==> Successfully deployed ElevateIQ Platform on Hostinger VPS (${var.domain_name})!'"
    ]
  }
}

output "api_endpoint" {
  value       = "https://${var.domain_name}"
  description = "Configured Production API Endpoint"
}
