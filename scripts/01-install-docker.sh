#!/bin/bash
# ./scripts/01-install-docker.sh
echo "=== NEBULA DOCKER INSTALLATION ==="

# Initial Preparation
sudo apt update
sudo apt install -y ca-certificates curl

# Add Docker repository
sudo install -m 0755 -d /etc/apt/keyrings
sudo curl -fsSL https://download.docker.com/linux/ubuntu/gpg -o /etc/apt/keyrings/docker.asc
sudo chmod a+r /etc/apt/keyrings/docker.asc
echo "deb [arch=$(dpkg --print-architecture) signed-by=/etc/apt/keyrings/docker.asc] https://download.docker.com/linux/ubuntu $(. /etc/os-release && echo "$VERSION_CODENAME") stable" | sudo tee /etc/apt/sources.list.d/docker.list > /dev/null

# Install Docker
sudo apt update
sudo apt install -y docker-ce docker-ce-cli containerd.io docker-buildx-plugin docker-compose-plugin

# Verify installation (use sudo because user is not yet in docker group)
sudo docker --version
sudo docker compose version

# Add current user to docker group
sudo usermod -aG docker $USER

echo "====================================================="
echo "✅ Docker installed successfully!"
echo ""
echo "⚠️  IMPORTANT: You must LOG OUT and LOG BACK IN"
echo "   for the Docker group changes to take effect."
echo ""
echo "   After logging in again, verify with: docker ps"
echo "====================================================="

