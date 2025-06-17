#!/bin/bash

echo "📝 Configuración inicial para Postiz + Nginx + SSL"

# Preguntar por variables necesarias
read -p "🌐 Ingresa el dominio (ej: blog.tudominio.com): " DOMAIN
read -p "📧 Ingresa el correo del administrador: " ADMIN_EMAIL
read -s -p "🔑 Ingresa la contraseña del administrador (será visible solo una vez): " ADMIN_PASSWORD
echo
read -s -p "🗄️ Ingresa la contraseña para PostgreSQL: " POSTGRES_PASSWORD
echo

# --------------------------------------------
# 1. Actualizar sistema e instalar dependencias
# --------------------------------------------
echo "🛠️ Actualizando sistema e instalando dependencias..."
sudo apt update && sudo apt upgrade -y
sudo apt install -y curl git nginx certbot python3-certbot-nginx docker.io docker-compose

# --------------------------------------------
# 2. Clonar Postiz y configurar entorno
# --------------------------------------------
echo "📦 Clonando repositorio de Postiz..."
git clone https://github.com/ramuell/postiz.git ~/postiz
cd ~/postiz

echo "⚙️ Configurando archivo .env..."
cp .env.example .env
cat <<EOF > .env
POSTIZ_DOMAIN=http://localhost
POSTIZ_PORT=3000
POSTGRES_PASSWORD=${POSTGRES_PASSWORD}
ADMIN_EMAIL=${ADMIN_EMAIL}
ADMIN_PASSWORD=${ADMIN_PASSWORD}
EOF

# --------------------------------------------
# 3. Iniciar Postiz con Docker
# --------------------------------------------
echo "🐳 Levantando Postiz con Docker Compose..."
docker compose up -d

# --------------------------------------------
# 4. Configurar Nginx
# --------------------------------------------
echo "🌐 Configurando Nginx como proxy inverso..."
sudo tee /etc/nginx/sites-available/postiz > /dev/null <<EOF
server {
    listen 80;
    server_name ${DOMAIN};

    location / {
        proxy_pass http://localhost:3000;
        proxy_set_header Host \$host;
        proxy_set_header X-Real-IP \$remote_addr;
        proxy_set_header X-Forwarded-For \$proxy_add_x_forwarded_for;
        proxy_set_header X-Forwarded-Proto \$scheme;
    }
}
EOF

sudo ln -s /etc/nginx/sites-available/postiz /etc/nginx/sites-enabled/
sudo nginx -t && sudo systemctl reload nginx

# --------------------------------------------
# 5. Obtener certificado SSL con Certbot
# --------------------------------------------
echo "🔐 Solicitando certificado SSL para ${DOMAIN}..."
sudo certbot --nginx -d ${DOMAIN} --non-interactive --agree-tos -m ${ADMIN_EMAIL}

# --------------------------------------------
# 6. Activar servicios al iniciar
# --------------------------------------------
echo "🚀 Habilitando Docker y Nginx al inicio..."
sudo systemctl enable docker
sudo systemctl enable nginx

# --------------------------------------------
# 7. Final
# --------------------------------------------
echo
echo "✅ ¡Listo! Tu instancia de Postiz está disponible en: https://${DOMAIN}"
echo "👤 Usuario administrador: ${ADMIN_EMAIL}"
echo "🔑 Contraseña: ${ADMIN_PASSWORD} (no se mostrará nuevamente)"
