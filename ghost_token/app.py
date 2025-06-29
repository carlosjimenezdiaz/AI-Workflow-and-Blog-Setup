import jwt
import time
from flask import Flask, jsonify
import os
from dotenv import load_dotenv

# Load env vars from .env file
load_dotenv()

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
