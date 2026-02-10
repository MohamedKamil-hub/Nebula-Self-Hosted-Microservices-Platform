#!/bin/bash
# Genera certificados auto-firmados para desarrollo
openssl req -x509 -nodes -days 365 -newkey rsa:2048 \
  -keyout nebula.key -out nebula.crt \
  -subj "/C=ES/ST=Madrid/L=Madrid/O=NEBULA/CN=*.nebula.test"
