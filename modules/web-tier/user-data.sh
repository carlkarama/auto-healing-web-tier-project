#!/bin/bash
set -euxo pipefail

# t4g.nano has 512 MiB RAM: create swap before package installation.
if [ ! -f /swapfile ]; then
  fallocate -l 1G /swapfile
  chmod 600 /swapfile
  mkswap /swapfile
fi
swapon /swapfile || true
if ! grep -q '^/swapfile ' /etc/fstab; then
  echo '/swapfile none swap sw 0 0' >> /etc/fstab
fi

# AL2023 repositories use S3 dual-stack endpoints reachable over IPv6.
for attempt in 1 2 3 4 5; do
  if dnf install -y nginx; then
    break
  fi
  if [ "$attempt" -eq 5 ]; then
    exit 1
  fi
  sleep 10
done

TOKEN=$(curl --fail --silent --show-error --max-time 10 -X PUT \
  -H 'X-aws-ec2-metadata-token-ttl-seconds: 60' \
  http://169.254.169.254/latest/api/token)
INSTANCE_ID=$(curl --fail --silent --show-error --max-time 10 \
  -H "X-aws-ec2-metadata-token: $TOKEN" \
  http://169.254.169.254/latest/meta-data/instance-id)

cat > /etc/nginx/nginx.conf <<NGINX
user nginx;
worker_processes auto;
error_log /var/log/nginx/error.log warn;
pid /run/nginx.pid;
events { worker_connections 256; }
http {
    include /etc/nginx/mime.types;
    default_type application/octet-stream;
    access_log off;
    sendfile on;
    server {
        listen 80 default_server;
        listen [::]:80 default_server;
        server_name _;
        root /usr/share/nginx/html;
        index index.html;
        add_header X-Web-Instance "$INSTANCE_ID" always;
        add_header Cache-Control "no-store" always;
    }
}
NGINX

mkdir -p /etc/systemd/system/nginx.service.d
cat > /etc/systemd/system/nginx.service.d/restart.conf <<'SERVICE'
[Service]
Restart=on-failure
RestartSec=2
SERVICE

nginx -t
systemctl daemon-reload
systemctl enable --now nginx
