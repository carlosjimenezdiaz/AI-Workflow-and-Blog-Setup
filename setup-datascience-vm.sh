#!/bin/bash

echo "🚀 Iniciando setup completo para VM de Data Science..."

# 1. Actualizar sistema
apt-get update && apt-get upgrade -y

# 2. Instalar paquetes esenciales
apt-get install -y \
    nano vim tree htop curl wget unzip git make \
    build-essential software-properties-common apt-transport-https ca-certificates gnupg lsb-release ufw tmux zsh

# 3. Instalar Python 3.11 y pip
add-apt-repository ppa:deadsnakes/ppa -y
apt-get update
apt-get install -y python3.11 python3.11-venv python3.11-dev python3-pip
update-alternatives --install /usr/bin/python python /usr/bin/python3.11 1

# 4. Instalar Docker y Docker Compose v2
mkdir -p /etc/apt/keyrings
curl -fsSL https://download.docker.com/linux/ubuntu/gpg | gpg --dearmor -o /etc/apt/keyrings/docker.gpg
echo \
  "deb [arch=$(dpkg --print-architecture) signed-by=/etc/apt/keyrings/docker.gpg] https://download.docker.com/linux/ubuntu \
  $(lsb_release -cs) stable" | tee /etc/apt/sources.list.d/docker.list > /dev/null

apt-get update
apt-get install -y docker-ce docker-ce-cli containerd.io docker-buildx-plugin docker-compose-plugin

# Habilitar Docker
systemctl enable docker
systemctl start docker

# Añadir usuario actual al grupo docker
usermod -aG docker $USER

# 5. Instalar Miniconda (Python data science stack)
cd /tmp
wget https://repo.anaconda.com/miniconda/Miniconda3-latest-Linux-x86_64.sh
bash Miniconda3-latest-Linux-x86_64.sh -b -p $HOME/miniconda
eval "$($HOME/miniconda/bin/conda shell.bash hook)"
conda init
source ~/.bashrc

# 6. Crear entorno base con librerías útiles
conda create -n ds python=3.11 -y
conda activate ds
conda install -y numpy pandas matplotlib seaborn scikit-learn jupyterlab notebook ipython requests beautifulsoup4 plotly openpyxl

# 7. Git config (ajusta tu nombre y correo)
git config --global user.name "Carlos Jimenez"
git config --global user.email "carlos@example.com"
git config --global init.defaultBranch main

# 8. Seguridad básica
ufw allow OpenSSH
ufw enable
apt-get install -y fail2ban

# 9. Alias y mejoras de productividad
echo "alias ll='ls -alF'" >> ~/.bashrc
echo "alias gs='git status'" >> ~/.bashrc
echo "alias gp='git pull'" >> ~/.bashrc
echo "alias dc='docker compose'" >> ~/.bashrc

# 10. Limpieza
apt-get autoremove -y
apt-get clean

echo "✅ Setup completado. Reinicia o ejecuta: source ~/.bashrc"
