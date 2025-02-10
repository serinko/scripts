#!/bin/bash

# SETUP ENV VARS HOSTNAME AND EMAIL FIRST!

# Ensure HOSTNAME and EMAIL environment variables are set
if [ -z "$HOSTNAME" ]; then
  echo "Error: HOSTNAME environment variable is not set."
  exit 1
fi

if [ -z "$EMAIL" ]; then
  echo "Error: EMAIL environment variable is not set."
  exit 1
fi

# 1. Install Certbot and obtain SSL certificate
echo "Installing Certbot and acquiring SSL certificate for $HOSTNAME..."

apt install -y certbot python3-certbot-nginx && \
certbot --nginx --non-interactive --agree-tos --redirect -m "$EMAIL" -d "$HOSTNAME"

# 2. Create the WebSocket configuration file for Nginx
CONF_FILE="/etc/nginx/sites-available/wss-config-nym"

echo "Creating WebSocket Nginx configuration file at $CONF_FILE..."

cat <<EOF > "$CONF_FILE"
server {
    listen 9001 ssl http2;
    listen [::]:9001 ssl http2;

    server_name ${HOSTNAME};

    ssl_certificate /etc/letsencrypt/live/${HOSTNAME}/fullchain.pem;
    ssl_certificate_key /etc/letsencrypt/live/${HOSTNAME}/privkey.pem;
    include /etc/letsencrypt/options-ssl-nginx.conf; # managed by Certbot
    ssl_dhparam /etc/letsencrypt/ssl-dhparams.pem; # managed by Certbot

    access_log /var/log/nginx/access.log;
    error_log /var/log/nginx/error.log;

    # Ignore favicon requests
    location /favicon.ico {
        return 204;
        access_log     off;
        log_not_found  off;
    }

    location / {

        add_header 'Access-Control-Allow-Origin' '*';
        add_header 'Access-Control-Allow-Credentials' 'true';
        add_header 'Access-Control-Allow-Methods' 'GET, POST, OPTIONS, HEAD';
        add_header 'Access-Control-Allow-Headers' '*';

        proxy_http_version 1.1;
        proxy_set_header Upgrade \$http_upgrade;
        proxy_set_header Connection "Upgrade";
        proxy_set_header X-Forwarded-For \$remote_addr;

        proxy_pass http://localhost:9000;
        proxy_intercept_errors on;
    }
}
EOF

# 3. Create the symlink to sites-enabled and test the configuration
echo "Creating symlink to sites-enabled..."
ln -s "/etc/nginx/sites-available/wss-config-nym" "/etc/nginx/sites-enabled/"

# Test nginx configuration
echo "Testing nginx configuration..."
nginx -t

if [ $? -eq 0 ]; then
  echo "Nginx configuration is valid. Restarting nginx..."
  systemctl reload nginx
else
  echo "Nginx configuration test failed. Please check the config."
  exit 1
fi

echo "Script completed successfully."
