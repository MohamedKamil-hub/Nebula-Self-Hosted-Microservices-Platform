#!/usr/bin/env python3
"""
Oedon Knock Client - Envía knock UDP al portero.
Uso: python3 knock.py <servidor_ip>

Config via env vars or .env in current/script directory:
  PORTERO_SECRET      (required)
  PORTERO_UDP_PORT    (default: 62201)
"""

import socket
import hmac
import hashlib
import time
import sys
import os
from pathlib import Path


def _load_dotenv():
    for candidate in [Path.cwd() / ".env", Path(__file__).resolve().parent / ".env"]:
        if candidate.is_file():
            with open(candidate) as f:
                for line in f:
                    line = line.strip()
                    if not line or line.startswith("#") or "=" not in line:
                        continue
                    k, v = line.split("=", 1)
                    os.environ.setdefault(k.strip(), v.strip().strip('"').strip("'"))
            return

_load_dotenv()

KNOCK_PORT = int(os.environ.get("PORTERO_UDP_PORT", "62201"))


def knock(server_ip: str):
    secret = os.environ.get("PORTERO_SECRET")
    if not secret:
        print("[!] PORTERO_SECRET not set. Set it in env or .env")
        sys.exit(1)

    ts = str(int(time.time()))
    mac = hmac.new(secret.encode(), ts.encode(), hashlib.sha256).hexdigest()
    payload = f"{ts}:{mac}".encode()

    sock = socket.socket(socket.AF_INET, socket.SOCK_DGRAM)
    sock.sendto(payload, (server_ip, KNOCK_PORT))
    sock.close()
    print(f"Knock enviado a {server_ip}:{KNOCK_PORT}")


if __name__ == "__main__":
    if len(sys.argv) != 2:
        print(f"Uso: python3 {sys.argv[0]} <servidor_ip>")
        sys.exit(1)
    knock(sys.argv[1])
