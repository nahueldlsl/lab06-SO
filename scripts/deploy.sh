#!/usr/bin/env bash
# Remote deployment script — executed on the Azure Ubuntu VM
set -euo pipefail

APP=$1          # "dummy-a" or "dummy-b"
ARTIFACT=$2     # path to the uploaded artifact (e.g. /tmp/dummy-b.tar.gz)

case "$APP" in
  dummy-a)
    echo "[deploy] Installing NGINX..."
    sudo apt-get install -y nginx

    echo "[deploy] Deploying static site..."
    sudo mkdir -p /var/www/dummy-a
    sudo tar -xzf "$ARTIFACT" -C /var/www/dummy-a --strip-components=1
    sudo cp /var/www/dummy-a/nginx.conf /etc/nginx/sites-available/dummy-a
    sudo ln -sf /etc/nginx/sites-available/dummy-a /etc/nginx/sites-enabled/dummy-a
    sudo rm -f /etc/nginx/sites-enabled/default
    sudo systemctl restart nginx
    sudo systemctl enable nginx

    echo "[deploy] Verifying dummy-a..."
    curl -sf http://localhost/ | grep -q "Hola Mundo DevOps" \
      && echo "[deploy] dummy-a OK" \
      || { echo "[deploy] dummy-a FAILED"; exit 1; }
    ;;

  dummy-b)
    echo "[deploy] Setting up Python environment..."
    sudo apt-get install -y python3 python3-pip python3-venv

    sudo mkdir -p /opt/dummy-b
    sudo tar -xzf "$ARTIFACT" -C /opt/dummy-b --strip-components=1
    cd /opt/dummy-b
    python3 -m venv .venv
    .venv/bin/pip install -r requirements.txt

    echo "[deploy] Installing systemd service..."
    sudo tee /etc/systemd/system/dummy-b.service > /dev/null <<'SERVICE'
[Unit]
Description=Dummy-B Flask API
After=network.target

[Service]
User=ubuntu
WorkingDirectory=/opt/dummy-b
ExecStart=/opt/dummy-b/.venv/bin/python app.py
Restart=always

[Install]
WantedBy=multi-user.target
SERVICE

    sudo systemctl daemon-reload
    sudo systemctl restart dummy-b
    sudo systemctl enable dummy-b

    echo "[deploy] Verifying dummy-b..."
    sleep 3
    curl -sf http://localhost:8080/health | grep -q '"status": "ok"' \
      && echo "[deploy] dummy-b OK" \
      || { echo "[deploy] dummy-b FAILED"; exit 1; }
    ;;

  *)
    echo "Unknown app: $APP"
    exit 1
    ;;
esac
