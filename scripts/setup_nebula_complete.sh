#!/bin/bash
# ==============================================================================
# SCRIPT DE PREPARACIÓN INTEGRAL - PROYECTO NEBULA
# ==============================================================================
# Prepara un entorno Ubuntu/Debian desde cero instalando Docker, 
# herramientas de red, monitoreo, seguridad y utilidades DevOps.
# ==============================================================================


#Instrucciones para ejecutarlo
#
# Dale permisos de ejecución:
#    chmod +x setup_nebula_complete.sh
#
# Ejecútalo:
#    ./setup_nebula_complete.sh


# para el script si hay errores
set -e

echo "[1/8] Iniciando actualización del sistema..."
sudo apt-get update && sudo apt-get upgrade -y

echo " [2/8] Limpiando instalaciones previas conflictivas de Docker..."
# previene el error que tuve de mezclar docker.io con docker-ce
for pkg in docker.io docker-doc docker-compose docker-compose-v2 podman-docker containerd runc; do 
    sudo apt-get remove -y $pkg || true
done

echo " [3/8] Instalando dependencias base y llaves GPG..."
sudo apt-get install -y ca-certificates curl gnupg lsb-release

# --- CONFIGURACIÓN REPO DOCKER (OFICIAL) ---
sudo mkdir -m 0755 -p /etc/apt/keyrings
[ -f /etc/apt/keyrings/docker.gpg ] && sudo rm /etc/apt/keyrings/docker.gpg
curl -fsSL https://download.docker.com/linux/ubuntu/gpg | sudo gpg --dearmor -o /etc/apt/keyrings/docker.gpg

echo \
  "deb [arch=$(dpkg --print-architecture) signed-by=/etc/apt/keyrings/docker.gpg] https://download.docker.com/linux/ubuntu \
  $(lsb_release -cs) stable" | sudo tee /etc/apt/sources.list.d/docker.list > /dev/null

# --- CONFIGURACIÓN REPO GITHUB CLI ---
[ -f /etc/apt/keyrings/githubcli-archive-keyring.gpg ] && sudo rm /etc/apt/keyrings/githubcli-archive-keyring.gpg
curl -fsSL https://cli.github.com/packages/githubcli-archive-keyring.gpg | sudo dd of=/usr/share/keyrings/githubcli-archive-keyring.gpg
echo "deb [arch=$(dpkg --print-architecture) signed-by=/usr/share/keyrings/githubcli-archive-keyring.gpg] https://cli.github.com/packages stable main" | sudo tee /etc/apt/sources.list.d/github-cli.list > /dev/null

# --- CONFIGURACIÓN PPA NEOVIM (Para versión reciente) ---
if ! grep -q "neovim-ppa/stable" /etc/apt/sources.list /etc/apt/sources.list.d/*; then
    sudo add-apt-repository -y ppa:neovim-ppa/stable
fi

sudo apt-get update

echo "🛠️/8] Instalando lista completa de herramientas..."

# paquetes solicitados:
PACKAGES=(
    # Core & Docker
    "docker-ce" "docker-ce-cli" "containerd.io" "docker-buildx-plugin" "docker-compose-plugin"
    
    # Servidor Web y Certificados
    "nginx" "nginx-extras" "certbot" "python3-certbot-nginx"
    
    # Seguridad
    "fail2ban" "ufw" "auditd" "unattended-upgrades"
    
    # Monitoreo y Red
    "htop" "iftop" "iotop" "netdata" "tcpdump" "bridge-utils" "dnsutils" "nmap"
    
    # Utilidades CLI y Editores
    "git" "curl" "wget" "vim" "neovim" "tmux" "tree" "ncdu" "jq" "zip" "unzip"
    
    # Lenguajes & Librerías
    "python3-pip" "libyaml-cpp-dev" 
    
    # DevOps Tools
    "ansible" "gh"
    
    # Bases de Datos (Cliente)
    "postgresql-client"
    
    # Pruebas de Carga (Testing)
    "apache2-utils" # Contiene 'ab' (Apache Bench)
    "siege"
    
    # Backups
    "rsnapshot" "duplicity"
)

sudo apt-get install -y "${PACKAGES[@]}"

echo " [5/8] Configurando usuario 'nebula-admin'..."
# Crea usuario si no existe
if id "nebula-admin" &>/dev/null; then
    echo "   El usuario 'nebula-admin' ya existe. Saltando creación."
else
    sudo adduser --gecos "" --disabled-password nebula-admin
    echo "   ⚠️PORTANTE: establece una contraseña para nebula-admin con 'sudo passwd nebula-admin'"
fi

# Añadir a grupos sudo y docker
sudo usermod -aG sudo nebula-admin
sudo usermod -aG docker nebula-admin
# Añadir usuario actual también a docker
sudo usermod -aG docker $USER

echo " [6/8] Configurando Firewall (UFW)..."
sudo ufw allow 22/tcp comment 'SSH'
sudo ufw allow 80/tcp comment 'HTTP'
sudo ufw allow 443/tcp comment 'HTTPS'
# no habilito (enable) automáticamente para evitar bloqueo de mi puerto SSH no estándar.
# ejecuta sudo ufw enable manualmente si estas seguro

echo " [7/8] Verificando instalación de Docker..."
if sudo docker run --rm hello-world > /dev/null; then
    echo "    Docker Engine instalado y funcionando correctamente."
else
    echo "   ups Hubo un problema arrancando el contenedor de prueba de Docker."
fi

echo " [8/8] Limpieza..."
sudo apt-get autoremove -y
sudo apt-get clean

echo "========================================================"
echo " PREPARACIÓN DE NEBULA COMPLETADA"
echo "========================================================"
echo "Pasos siguientes:"
echo "1. Ejecuta 'sudo passwd nebula-admin' para ponerle contraseña al nuevo usuario."
echo "2. Ejecuta 'sudo ufw enable' para encender el firewall."
echo "3. Cierra sesión y vuelve a entrar para aplicar los permisos de grupo Docker."
echo "========================================================"
