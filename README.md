# 🚀 Nebula Self-Hosted PaaS

**Self-hosted platform for deploying web applications on modest hardware**

[![Status](https://img.shields.io/badge/Status-In_Development-yellow)](https://github.com/MohamedKamil-hub/nebula-selfhosted-paas)
[![Docker](https://img.shields.io/badge/Docker-Ready-2496ED?logo=docker&logoColor=white)](https://www.docker.com/)
[![Ubuntu](https://img.shields.io/badge/Ubuntu-24.04_LTS-E95420?logo=ubuntu&logoColor=white)](https://ubuntu.com/)
[![License](https://img.shields.io/badge/License-MIT-green.svg)](LICENSE)

> A lightweight alternative to Heroku, Render, or Vercel — built for small teams, developers, and homelabs who want **full control** without recurring SaaS costs.

A comprehensive self-hosted Platform as a Service (PaaS) built with Docker Compose, featuring multiple applications including static web hosting, Python applications, WordPress, and advanced monitoring/proxy management.

## 📋 Table of Contents

- [What is NEBULA?](#-what-is-nebula)
- [Key Features](#-key-features)
- [Architecture](#️-architecture)
- [Quick Start](#-quick-start)
- [Project Structure](#-project-structure)
- [Available Applications](#-available-applications)
- [Prerequisites](#️-prerequisites)
- [Docker Commands](#-docker-commands)
- [Task Commands](#-task-commands)
- [Service Endpoints](#-service-endpoints)
- [Docker Network Architecture](#️-docker-network-architecture)
- [Logging & Monitoring](#-logging--monitoring)
- [Configuration](#️-configuration)
- [Performance Benchmarks](#-performance-benchmarks)
- [Security Features](#-security-features)
- [Troubleshooting](#-troubleshooting)
- [Contributing](#-contributing)
- [License](#-license)
- [Author](#-author)
- [Acknowledgments](#-acknowledgments)
- [Additional Resources](#-additional-resources)

## 🎯 What is NEBULA?

NEBULA is a self-managed server platform that lets you deploy and manage web applications using Docker containers on hardware as modest as **2 vCPU / 4 GB RAM**. It integrates:

- 🔐 **Automatic SSL** certificates via Let's Encrypt
- 📊 **Real-time monitoring** with Netdata (consuming ~100-200 MB RAM)
- 🛡️ **Security hardening** with UFW firewall, Fail2Ban, and SSH key-only access
- 🐳 **Docker-based deployments** for portability and isolation

Perfect for startups, homelab enthusiasts, or anyone tired of vendor lock-in.

## ✨ Key Features

| Feature | Description |
|---------|-------------|
| **Zero SaaS Costs** | Host on your own VPS or hardware — pay only for the server |
| **Data Sovereignty** | Your data stays under your control, always |
| **Lightweight Monitoring** | Netdata uses up to 88% less RAM than Prometheus in low-scale setups |
| **Automated SSL** | Let's Encrypt certificates renew automatically via Nginx Proxy Manager |
| **Battle-Tested Security** | SSH hardening, firewall rules, and intrusion prevention out of the box |

## 🏗️ Architecture

```
Internet → UFW Firewall → Nginx Proxy Manager (SSL) → Docker Containers
                                                         ├─ App 1
                                                         ├─ App 2
                                                         └─ Netdata (Monitoring)
```

**Tech Stack:**
- **OS:** Ubuntu 24.04 LTS (kernel 6.8.0-90 recommended for stability)
- **Containerization:** Docker Engine + Docker Compose v2
- **Reverse Proxy:** Nginx Proxy Manager
- **Monitoring:** Netdata Agent
- **Security:** UFW, Fail2Ban, SSH with public key authentication

## 🚀 Quick Start

### Prerequisites
- Ubuntu 24.04 LTS server (VPS or local)
- Root/sudo access
- Domain name (optional, can use IP or DuckDNS)
- Docker Engine: v20.10+
- Docker Compose: v1.29+
- Task Runner: (Optional) for task automation
- Linux/Unix System: Ubuntu 20.04+, Debian, CentOS
- Disk Space: Minimum 20GB
- Memory: Minimum 2GB (4GB+ recommended)

### Installation

```bash
# Clone the repository
git clone https://github.com/MohamedKamil-hub/nebula-selfhosted-paas.git
cd nebula-selfhosted-paas

# Copy environment template
cp .env.example .env
# Edit with your configuration
nano .env

# Create Required Directories
mkdir -p data/npm data/letsencrypt logs/npm logs/netdata logs/static
chmod 755 data logs

# Create Docker Network
docker network create nebula-network

# Run the complete setup script
sudo ./scripts/setup_nebula_complete.sh

# Start services
docker compose up -d
```

**That's it!** Access your monitoring dashboard at `http://your-server-ip:19999`

Verify Services:
```bash
docker compose ps
```

Initial Access:
- Nginx Proxy Manager: `http://localhost:81`
- Netdata Dashboard: `http://localhost:19999`

## 📂 Project Structure

```
nebula-selfhosted-paas/
├── apps/ # Example applications
│ ├── python-app/
│ │ └── docker-compose.yml
│ ├── static-web/
│ │ └── html/
│ └── wordpress-app/
├── config/ # Configuration files
│ ├── fail2ban/ # Intrusion prevention rules
│ ├── netdata/ # Monitoring configuration
│ ├── nginx/ # Reverse proxy settings
│ └── ssh/ # SSH hardening configs
├── data/ # Persistent data volumes
│ ├── npm/ # Nginx Proxy Manager data
│ └── letsencrypt/ # SSL certificates
├── docs/ # Documentation & diagrams
├── infrastructure/ # Docker compose files
│ └── docker/
│ ├── apps/ # Application containers
│ └── monitoring/ # Monitoring stack
├── logs/ # Application logs
│ ├── npm/ # Proxy manager logs
│ ├── netdata/ # Monitoring logs
│ └── static/ # Static web server logs
├── scripts/ # Automation scripts
│ ├── deploy.sh # App deployment helper
│ ├── setup_nebula_complete.sh # Initial server setup
│ └── backup-nebula.sh # Backup script
├── tests/ # Test suites
│ ├── integration/
│ ├── load/
│ └── security/
├── docker-compose.yml # Main compose file
├── docker-compose.prod.yml # Production overrides
├── Taskfile.yaml # Task automation (requires Task)
├── Makefile # Make automation
├── .env.example # Environment template
├── README.md # This file
└── LICENSE # License file
```

## 🎯 Available Applications

### 1. **Nginx Proxy Manager** (nebula-proxy)

**Purpose:** Reverse proxy and SSL certificate management

| Property | Value |
|----------|-------|
| Image | `jc21/nginx-proxy-manager:latest` |
| Container | `nebula-proxy` |
| Restart | `unless-stopped` |
| Ports | `80:80`, `81:81`, `443:443`, `10443:443` |
| Health Check | `http://localhost:81` (30s interval) |
| Volumes | `./data/npm:/data`, `./data/letsencrypt:/etc/letsencrypt`, `./logs/npm:/var/log/nginx` |

**Features:**
- Reverse proxy and load balancing
- Automatic SSL/TLS with Let's Encrypt
- Admin panel on port 81
- IPv6 disabled (`DISABLE_IPV6=true`)
- JSON logging with 10MB max size, 3 files, compression enabled

**Access:**
- Admin Panel: `http://localhost:81`
- Default credentials: Check Nginx Proxy Manager documentation

### 2. **Netdata Monitoring** (nebula-monitor)

**Purpose:** Real-time system, container, and application monitoring

| Property | Value |
|----------|-------|
| Image | `netdata/netdata:latest` |
| Container | `nebula-monitor` |
| Restart | `unless-stopped` |
| Port | `19999:19999` |
| Health Check | `http://localhost:19999/api/v1/info` (60s interval) |

**Volumes:**
- `netdataconfig:/etc/netdata`
- `netdatalib:/var/lib/netdata`
- `netdatacache:/var/cache/netdata`
- `./logs/netdata:/var/log/netdata`
- `/proc:/host/proc:ro`
- `/sys:/host/sys:ro`
- `/var/run/docker.sock:/var/run/docker.sock:ro`
- `/etc/passwd:/host/etc/passwd:ro`
- `/etc/group:/host/etc/group:ro`
- `/etc/localtime:/etc/localtime:ro`

**Capabilities:** `SYS_PTRACE`, `SYS_ADMIN`, `DAC_READ_SEARCH`

**Security Options:** AppArmor: unconfined, Seccomp: unconfined

**Environment Variables:**
```yaml
NETDATA_CLAIM_URL: "https://app.netdata.cloud"
NETDATA_HOSTNAME: "nebula-server"
DOCKER_HOST: "unix:///var/run/docker.sock"
```

**Features:**
- Real-time system monitoring
- Container performance metrics
- Docker integration
- Process and network tracking

**Access:**
- Dashboard: `http://localhost:19999`

### 3. **Static Web Server** (nebula-static)

**Purpose:** Serve static HTML/CSS/JavaScript content

| Property | Value |
|----------|-------|
| Image | `nginx:alpine` |
| Container | `nebula-static` |
| Restart | `unless-stopped` |
| Port | `80:80` (internal) |
| Health Check | `http://localhost:80` (60s interval) |

**Volumes:**
- `./apps/static-web/html:/usr/share/nginx/html:ro`
- `./logs/static:/var/log/nginx:rw`

**Features:**
- Lightweight Alpine Linux Nginx
- Serve static content
- Read-only content volume
- Access via proxy manager
- JSON logging with 10MB max size, 3 files, compression enabled

**Setup:**
- Add your HTML files to `apps/static-web/html/`
- Configure a proxy host in Nginx Proxy Manager pointing to `nebula-static:80`

### 4. **Python Application** (python-app)

**Purpose:** Run custom Python applications

| Property | Value |
|----------|-------|
| Build | `./apps/python-app/Dockerfile` |
| Container | `python-app` |
| Restart | `unless-stopped` |
| Network | `nebula-network` |

**Docker Compose Location:** `apps/python-app/docker-compose.yml`

**Setup:**
- Navigate to `apps/python-app/`
- Ensure Dockerfile is configured correctly
- Add `requirements.txt` and your Python code
- Start with: `docker-compose up -d`
- Configure proxy manager to route traffic to `python-app`

### 5. **WordPress Application** (wordpress-app)

**Purpose:** Run WordPress for blogging/CMS needs

**Status:** Directory available at `apps/wordpress-app/`

**Setup Required:**
- Create `docker-compose.yml` in `apps/wordpress-app/`
- Configure WordPress and MySQL services
- Connect to `nebula-network`
- Configure SSL through Nginx Proxy Manager

## 🛠️ Prerequisites

See Quick Start section above.

## 🎮 Docker Commands

**Basic Commands:**

```bash
# Start all services
docker compose up -d

# Stop all services
docker compose down

# Restart services
docker compose restart

# View running services
docker compose ps

# View logs (all services)
docker compose logs -f

# View logs (specific service)
docker compose logs -f nebula-proxy

# Stop a specific service
docker compose stop service_name

# Start a specific service
docker compose start service_name

# Rebuild images
docker compose build

# Remove stopped containers and unused images
docker compose down -v
docker system prune -a
```

**Advanced Commands:**

```bash
# Execute command in running container
docker compose exec nebula-proxy sh

# View service configuration
docker compose config

# Validate docker-compose.yml
docker compose config --quiet

# Export compose file with resolved values
docker compose config > docker-compose.resolved.yml

# Scale services (if applicable)
docker compose up -d --scale python-app=3

# Update and rebuild
docker compose up -d --build --remove-orphans

# View resource usage
docker stats

# Remove specific container
docker compose rm -f service_name
```

## 📋 Task Commands

Using Task Runner (requires installation):

```bash
# List all available tasks
task

# Start the entire NEBULA stack
task up

# Stop and remove containers
task down

# Restart all services
task restart

# View logs stream
task logs

# Show running containers
task status

# Real-time resource monitoring
task monitor

# Execute backup procedure
task backup

# Audit security layers (Firewall & IPS)
task security-check

# Update code from Git and redeploy
task update

# Remove unused Docker data
task clean
```

Task File Location: All tasks are defined in `Taskfile.yaml` at the repository root.

## 🌐 Service Endpoints

**External Access:**

| Service | URL | Port | Purpose |
|---------|-----|------|---------|
| Nginx Proxy Manager | http://localhost:81 | 81 | Admin panel for proxy configuration |
| Netdata | http://localhost:19999 | 19999 | Real-time monitoring dashboard |
| Static Web | http://localhost:80 (via proxy) | 80 | Static content (configured domain) |
| Python App | http://localhost:5000 (via proxy) | 5000 | API endpoint (configured domain) |
| HTTPS | https://localhost:443 | 443 | SSL-secured traffic |
| Alt HTTPS | https://localhost:10443 | 10443 | Alternative HTTPS port |

**Internal Network (Docker Network: nebula-network):**

| Service | Host:Port | Purpose |
|---------|-----------|---------|
| Nginx Proxy Manager | nebula-proxy:81 | Proxy API |
| Netdata | nebula-monitor:19999 | Monitoring API |
| Static Web | nebula-static:80 | Web server |
| Python App | python-app:5000 | Application API |

**Health Check Endpoints:**
- Nginx Proxy Manager: `http://localhost:81/health` (30s interval)
- Netdata: `http://localhost:19999/api/v1/info` (60s interval)
- Static Web: `http://localhost:80/` (60s interval)

## 🏗️ Docker Network Architecture

**Network Details:**
- Type: Bridge network (Docker-managed)
- Status: External (manually created)
- DNS Resolution: Services can reach each other by container name
- Example: `nebula-proxy` → `http://nebula-static:80`

```
┌─────────────────────────────────────────────────────┐
│ Docker Network: nebula-network                      │
├─────────────────────────────────────────────────────┤
│                                                     │
│ ┌─────────────────────────────────────────────┐     │
│ │ nebula-proxy (Nginx Proxy Manager)          │     │
│ │ Ports: 80, 81, 443, 10443                   │     │
│ └─────────────────────────────────────────────┘     │
│                │                                    │
│ ┌──────────────┼───────────────┐                    │
│ │              │               │                    │
│ ┌─────▼──────┐ ┌─────▼──────┐ ┌─────▼──────┐       │
│ │ nebula-    │ │ nebula-    │ │ python-app  │       │
│ │ monitor    │ │ static     │ │ :5000       │       │
│ │ :19999     │ │ :80        │ └────────────┘       │
│ └────────────┘ └────────────┘                       │
│                                                     │
└─────────────────────────────────────────────────────┘
```

## 📊 Logging & Monitoring

**Log Locations:**

```
logs/
├── npm/ # Nginx Proxy Manager logs (access.log, error.log)
├── netdata/ # Netdata logs
└── static/ # Static web server logs
```

**Logging Configuration:**
- All services use JSON logging driver with automatic rotation and compression.
- Nginx Proxy Manager: 10MB max, 3 files
- Netdata: 20MB max, 5 files
- Static Web: 10MB max, 3 files

**View Logs:**

```bash
# All services
docker compose logs -f

# Specific service
docker compose logs -f nebula-proxy

# Last 50 lines
docker compose logs --tail 50 nebula-proxy

# Specific time range
docker compose logs --since 2024-01-01 --until 2024-01-02

# Show timestamps
docker compose logs --timestamps=true
```

**Monitoring with Netdata:**
- Access Dashboard: `http://localhost:19999`
- View Metrics: CPU, Memory, Disk I/O, Network traffic, Container performance, System processes
- Alerts: Configure custom alerts in Netdata UI

## ⚙️ Configuration

**Environment Variables:**

Create a `.env` file from the template:

```bash
cp .env.example .env
```

Sample `.env`:

```
# Proxy Manager
NPM_DATABASE_HOST=npm-db
NPM_DATABASE_NAME=npm
NPM_DATABASE_USER=npm_user
NPM_DATABASE_PASSWORD=secure_password

# Netdata
NETDATA_HOSTNAME=nebula-server
NETDATA_CLAIM_TOKEN=your_claim_token
NETDATA_CLAIM_URL=https://app.netdata.cloud

# Python App
PYTHON_PORT=5000
DEBUG=False

# SSL/TLS
LETSENCRYPT_EMAIL=admin@example.com
```

**Docker Compose Overrides:**

```bash
docker compose -f docker-compose.yml -f docker-compose.prod.yml up -d
```

**Volume Management:**

```bash
# List volumes
docker volume ls

# Inspect volume
docker volume inspect nebula-selfhosted-paaS_netdatalib

# Remove unused volumes
docker volume prune

# Backup volume
docker run --rm -v nebula-selfhosted-paas_netdatalib:/data \
  -v $(pwd):/backup \
  alpine tar czf /backup/netdata-backup.tar.gz -C /data .
```

## 📊 Performance Benchmarks

| Metric | NEBULA (Netdata) | Alternative (Prometheus) |
|--------|------------------|--------------------------|
| RAM Usage (Idle) | ~150 MB | ~800-1200 MB |
| Dashboard Load Time | <3 seconds | 5-10 seconds |
| Configuration Complexity | One-line install | Multi-step setup |
| Data Retention | Real-time only | Requires persistent storage |

*Benchmarks based on 2 vCPU / 4 GB RAM VPS running 2-3 containerized apps*

## 🔒 Security Features

- **SSH Hardening:** Key-only authentication, non-standard port, root login disabled
- **Firewall Rules:** UFW blocks all ports except 80, 443, and custom SSH
- **Intrusion Prevention:** Fail2Ban auto-bans IPs after 5 failed login attempts
- **Container Isolation:** Docker namespaces and cgroups prevent privilege escalation
- **Automatic Updates:** Let's Encrypt certificates renew every 90 days

**Network Security:**

```bash
# Example: Restrict SSH and allow only HTTP/HTTPS
sudo ufw default deny incoming
sudo ufw default allow outgoing
sudo ufw allow 22/tcp
sudo ufw allow 80/tcp
sudo ufw allow 443/tcp
sudo ufw allow 19999/tcp # For admin monitoring only
sudo ufw enable
```

**SSL/TLS Certificates:**
- Use Let's Encrypt via Nginx Proxy Manager
- Auto-renewal enabled
- Certificates stored in `./data/letsencrypt/`

**Backup & Disaster Recovery:**

```bash
# Manual backup
task backup
# Or using bash
bash scripts/backup-nebula.sh

# Automated backup (add to cron)
0 2 * * * cd /path/to/nebula-selfhosted-paas && task backup
```

**Resource Limits:**

Add to `docker-compose.yml`:

```yaml
services:
  nebula-proxy:
    deploy:
      resources:
        limits:
          cpus: '1'
          memory: 512M
        reservations:
          cpus: '0.5'
          memory: 256M
```

**Regular Updates:**

```bash
# Update all images
task update
# Or manually
docker compose pull
docker compose up -d
```

## 🐛 Troubleshooting

**Service Won't Start:**

```bash
# Check logs
docker compose logs nebula-proxy

# Verify port availability
sudo netstat -tulpn | grep LISTEN

# Check network
docker network ls
docker network inspect nebula-network
```

**Network Connectivity Issues:**

```bash
# Test DNS resolution between containers
docker compose exec python-app ping nebula-static

# Check network connectivity
docker compose exec python-app curl http://nebula-proxy:81/health

# Verify network settings
docker inspect nebula-network
```

**Disk Space Issues:**

```bash
# Check disk usage
docker system df

# Remove unused data
docker system prune -a

# Clean logs
find logs/ -name "*.log*" -delete
```

**Performance Issues:**

```bash
# Monitor resource usage
docker stats

# Run task monitoring
task monitor

# Check Netdata dashboard
http://localhost:19999
```

**Certificate Issues:**

```bash
# Check certificate status in Nginx Proxy Manager UI
http://localhost:81

# Manual renewal (if needed)
docker compose exec nebula-proxy certbot renew --force-renewal
```

**Container Keeps Restarting:**

```bash
# Check restart policy
docker inspect nebula-proxy | grep -A 5 RestartPolicy

# View detailed logs
docker compose logs --tail 100 service_name
```

## 🤝 Contributing

This project welcomes contributions! To get started:

1. Fork the repository
2. Create a feature branch (`git checkout -b feature/amazing-feature`)
3. Commit your changes (`git commit -m 'Add amazing feature'`)
4. Push to the branch (`git push origin feature/amazing-feature`)
5. Open a Pull Request

## 📝 License

This project is licensed under the MIT License - see the [LICENSE](LICENSE) file for details.

## 👤 Author

**Mohamed Kamil El Kouarti Mechhidan**  
*Student, 2º SMR PROMETEO by thePower*  
Project Tutor: Raúl  
📧 Contact: [GitHub Profile](https://github.com/MohamedKamil-hub)

## 🙏 Acknowledgments

- **Netdata** for lightweight, real-time monitoring
- **Docker** for containerization simplicity
- **Nginx Proxy Manager** for making SSL management painless
- **Let's Encrypt** for free SSL certificates
- The open-source community for making self-hosting accessible

## 🎓 Additional Resources

- Docker Documentation
- Docker Compose Reference
- Nginx Proxy Manager Docs
- Netdata Documentation
- Task Runner Docs

<div align="center">
**⭐ If you find NEBULA useful, consider starring the repo!**  
Made with ❤️ for students, developers, and self-hosting enthusiasts  
</div>

Last Updated: February 9, 2026  
Maintained by: MohamedKamil-hub
