#!/bin/bash
set -e

# === Posicionarse en el directorio del script ===
cd "$(dirname "$0")"

# === Validar y cargar archivo .env ===
if [ ! -f .env ]; then
  echo "❌ Archivo .env no encontrado. Crea uno con la variable GHOST_ADMIN_API_KEY"
  exit 1
fi

echo "📦 Cargando variables desde .env..."
export $(grep -v '^#' .env | xargs)

# === Crear requirements.txt ===
echo "✅ Generando requirements.txt..."
cat <<EOF > requirements.txt
flask
pyjwt
gunicorn
EOF

# === Crear Dockerfile ===
echo "✅ Generando Dockerfile..."
cat <<'EOF' > Dockerfile
FROM python:3.11-slim

WORKDIR /app
COPY requirements.txt .
RUN pip install --no-cache-dir -r requirements.txt

COPY app.py .

CMD ["gunicorn", "--bind", "0.0.0.0:3000", "app:app"]
EOF

# === Crear docker-compose.yml ===
echo "✅ Generando docker-compose.yml..."
cat <<EOF > docker-compose.yml
services:
  ghost-token:
    build: .
    container_name: ghost_token
    env_file:
      - .env
    ports:
      - "3030:3000"
    restart: unless-stopped
EOF

# === Crear app.py ===
echo "✅ Generando app.py..."
cat <<'EOF' > app.py
import jwt
import time
from flask import Flask, jsonify
import os

app = Flask(__name__)

@app.route("/ghost-token", methods=["GET"])
def get_token():
    key = os.environ.get("GHOST_ADMIN_API_KEY")
    if not key or ":" not in key:
        return jsonify({"error": "Invalid Admin API Key"}), 400

    key_id, secret = key.split(":")
    iat = int(time.time())
    exp = iat + 5 * 60

    header = {
        "alg": "HS256",
        "kid": key_id,
        "typ": "JWT"
    }

    payload = {
        "iat": iat,
        "exp": exp,
        "aud": "/admin/"
    }

    token = jwt.encode(payload, bytes.fromhex(secret), algorithm="HS256", headers=header)
    return jsonify({"token": token})

if __name__ == "__main__":
    app.run(host="0.0.0.0", port=3000)
EOF

# === Construir e iniciar el contenedor ===
echo "🚀 Levantando Ghost Token service..."
docker compose down || true
docker compose build
docker compose up -d

echo "✅ Ghost Token está corriendo en http://localhost:3030/ghost-token"
