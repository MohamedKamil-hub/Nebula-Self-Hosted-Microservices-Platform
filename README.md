# NEBULA: Self-Managed Server for Low-Resource Hardware

![Badge](https://img.shields.io/badge/Status-MVP-success) ![Badge](https://img.shields.io/badge/Docker-Enabled-blue) ![Badge](https://img.shields.io/badge/Netdata-Monitoring-green)

**NEBULA** is a lightweight, self-hosted alternative to SaaS platforms like Heroku or Render. [cite_start]It is designed to deploy containerized web applications on modest hardware (2 vCPU / 4 GB RAM) while ensuring data sovereignty and security[cite: 41, 44].

## 🎯 Objectives
* [cite_start]**Deploy** a resource-efficient server for multiple web apps[cite: 44].
* [cite_start]**Automate** deployment workflows via Docker Compose[cite: 45].
* [cite_start]**Monitor** in real-time using Netdata (consuming <200 MB RAM)[cite: 46].
* [cite_start]**Secure** the infrastructure with strict SSH, UFW, and Fail2Ban[cite: 42].

## 🛠️ Architecture
* [cite_start]**OS:** Ubuntu Server 24.04 LTS (Kernel 6.8.0-90 recommended)[cite: 209].
* [cite_start]**Proxy:** Nginx Proxy Manager (Auto SSL via Let's Encrypt)[cite: 75].
* [cite_start]**Monitoring:** Netdata Agent[cite: 76].
* [cite_start]**Security:** UFW, Fail2Ban, Key-based SSH[cite: 77].

## 🚀 Quick Start
1. Clone the repo: `git clone https://github.com/MohamedKamil-hub/nebula.git`
2. Run hardening script: `sudo ./scripts/02-hardening.sh`
3. Start services: `docker compose up -d`
