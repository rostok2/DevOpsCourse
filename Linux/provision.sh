#!/bin/bash
set -e

echo "=== Крок 1: Встановлення залежностей ==="
apt-get update
apt-get install -y curl gnupg2 ca-certificates lsb-release ubuntu-keyring

echo "=== Крок 2: Додавання офіційного ключа та репозиторію Nginx ==="
curl https://nginx.org/keys/nginx_signing.key | gpg --dearmor \
    | tee /usr/share/keyrings/nginx-archive-keyring.gpg >/dev/null

echo "deb [signed-by=/usr/share/keyrings/nginx-archive-keyring.gpg] \
http://nginx.org/packages/ubuntu $(lsb_release -cs) nginx" \
    | tee /etc/apt/sources.list.d/nginx.list

echo "=== Крок 3: Встановлення Nginx ==="
apt-get update
apt-get install -y nginx

echo "=== Крок 4: Запуск та перевірка ==="
systemctl enable nginx
systemctl start nginx

echo "Nginx встановлено!"