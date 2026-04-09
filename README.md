
1.  **El Bootstrap (Instalación base):** Ejecutar un único script (`install.sh`) que instale Docker, configure el firewall, instale a tu Portero Digital y coloque tu binario `oedon` en el sistema para que funcione como un comando global.
2.  **El Uso (Día a día):** Usar exclusivamente tu binario `oedon` para levantar las cosas.


**1. Instalar el Sistema Oedon**
```bash
git clone https://github.com/tu-usuario/Oedon.git
cd Oedon
sudo bash install.sh
```
*(Ese comando, por detrás y sin que el usuario haga nada, instala Docker, blinda el servidor con Fail2ban/UFW, genera las claves secretas y activa el comando `oedon`).*

**2. Desplegar todo**
```bash
sudo oedon deploy
```
*(Y este comando lee tu `apps.list` y levanta WordPress, Python y Nginx).*

