#!/bin/bash

# SETUP ENV VAR HOSTNAME FIRST!

# Ensure HOSTNAME environment variable is set
if [ -z "$HOSTNAME" ]; then
  echo "Error: HOSTNAME environment variable is not set."
  exit 1
fi

# Create the nginx configuration file in /etc/nginx/sites-available/
CONF_FILE="/etc/nginx/sites-available/${HOSTNAME}"

echo "Creating nginx configuration file at $CONF_FILE..."

cat <<EOF > "$CONF_FILE"
server {
    listen 80;
    listen [::]:80;

    # Replace <HOSTNAME> with your domain name
    server_name ${HOSTNAME};

    location / {
        proxy_pass http://127.0.0.1:8080;
        proxy_set_header X-Real-IP \$remote_addr;
        proxy_set_header Host \$host;
        proxy_set_header X-Forwarded-For \$proxy_add_x_forwarded_for;
    }
}
EOF

# Check if nginx sites-enabled symlink exists and unlink if necessary
if [ -L "/etc/nginx/sites-enabled/${HOSTNAME}" ]; then
  echo "Removing existing symlink in /etc/nginx/sites-enabled/"
  unlink "/etc/nginx/sites-enabled/${HOSTNAME}"
fi

# Create the symlink to sites-enabled and test the configuration
echo "Creating symlink to sites-enabled..."
ln -s "/etc/nginx/sites-available/${HOSTNAME}" "/etc/nginx/sites-enabled/${HOSTNAME}"

# Test nginx configuration and restart nginx
echo "Testing nginx configuration..."
nginx -t

if [ $? -eq 0 ]; then
  echo "Nginx configuration is valid. Restarting nginx..."
  systemctl daemon-reload
  systemctl restart nginx
else
  echo "Nginx configuration test failed. Please check the config."
  exit 1
fi

echo "Script completed successfully."
