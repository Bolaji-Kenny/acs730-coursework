#!/usr/bin/env bash
set -euo pipefail

# Deploys a simple static web page served by nginx,
# owned by the least-privilege 'webapp' service user.

APP_DIR="/usr/share/nginx/html"
SERVICE_USER="webapp"

echo "Writing web content..."
sudo tee "${APP_DIR}/index.html" > /dev/null <<'EOF'
<!DOCTYPE html>
<html>
<head><title>ACS730 Week 2</title></head>
<body>
  <h1>Hello from acs730-week2</h1>
  <p>Deployed by deploy-web.sh and managed by systemd.</p>
</body>
</html>
EOF

echo "Setting least-privilege ownership on web content..."
sudo chown -R "${SERVICE_USER}:${SERVICE_USER}" "${APP_DIR}"

echo "Enabling and starting nginx..."
sudo systemctl enable nginx
sudo systemctl start nginx

echo "Deployment complete. Service status:"
sudo systemctl status nginx --no-pager



