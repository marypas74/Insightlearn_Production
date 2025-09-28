#!/bin/bash
# Script per configurare nginx proxy per InsightLearn

echo "🔧 Configurazione nginx proxy per InsightLearn..."

# Installa nginx se non presente
if ! command -v nginx &> /dev/null; then
    echo "📦 Installazione nginx..."
    sudo apt update
    sudo apt install -y nginx
fi

# Crea certificato self-signed
echo "🔐 Creazione certificato SSL..."
sudo mkdir -p /etc/ssl/private
sudo openssl req -x509 -nodes -days 365 -newkey rsa:2048 \
    -keyout /etc/ssl/private/nginx-selfsigned.key \
    -out /etc/ssl/certs/nginx-selfsigned.crt \
    -subj "/C=IT/ST=Italy/L=Rome/O=InsightLearn/CN=192.168.1.103"

# Backup configurazione nginx esistente
sudo cp /etc/nginx/sites-available/default /etc/nginx/sites-available/default.backup

# Copia la nuova configurazione
sudo cp /home/mpasqui/Kubernetes/nginx-proxy.conf /etc/nginx/sites-available/insightlearn
sudo ln -sf /etc/nginx/sites-available/insightlearn /etc/nginx/sites-enabled/

# Disabilita configurazione default
sudo rm -f /etc/nginx/sites-enabled/default

# Testa configurazione
sudo nginx -t

# Riavvia nginx
sudo systemctl restart nginx
sudo systemctl enable nginx

echo "✅ Nginx proxy configurato!"
echo "🌐 InsightLearn HTTPS: https://192.168.1.103"
echo "🌐 InsightLearn HTTP: http://192.168.1.103"