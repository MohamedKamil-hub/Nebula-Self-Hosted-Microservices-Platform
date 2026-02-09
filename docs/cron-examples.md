# Ejemplos de Configuración Cron para Nebula PaaS

## 🚀 Despliegue Automático

Ejecutar cada 5 minutos para actualización automática:

```bash
*/5 * * * * /ruta/absoluta/al/proyecto/scripts/deploy.sh >> /var/log/deploy.log 2>&1
```

## 💾 Backups Automáticos

Ejecutar backup diario a las 2 AM:

```bash
0 2 * * * /ruta/absoluta/al/proyecto/scripts/backup-nebula.sh >> /var/log/backup.log 2>&1
```

## 🔒 Rotación de Logs

Limpiar logs antiguos diariamente a medianoche:

```bash
0 0 * * * find /ruta/absoluta/al/proyecto/logs -name "*.log" -mtime +7 -delete
```

## 📋 Configuración Completa Ejemplo

Crea un archivo `crontab` con:

```bash
# ============================================
# NEBULA PAAS - CRON CONFIGURATION
# ============================================
# Auto-deploy every 5 minutes
*/5 * * * * /home/USER/proyecto_intermodular/nebula-selfhosted-paas/scripts/deploy.sh >> /home/USER/deploy.log 2>&1

# Daily backup at 2 AM
0 2 * * * /home/USER/proyecto_intermodular/nebula-selfhosted-paas/scripts/backup-nebula.sh >> /home/USER/backup.log 2>&1

# Weekly cleanup of old backups (Sundays at 3 AM)
0 3 * * 0 find /home/USER/proyecto_intermodular/nebula-selfhosted-paas/backups -type d -mtime +30 -exec rm -rf {} \; 2>/dev/null
```

## 🔧 Cómo Instalar

1. Edita tu crontab:
   ```bash
   crontab -e
   ```

2. Añade las líneas correspondientes, ajustando las rutas.

3. Verifica la configuración:
   ```bash
   crontab -l
   ```

## ⚠️ Notas Importantes

- Reemplaza `USER` por tu nombre de usuario real
- Reemplaza las rutas según tu instalación
- Los logs se guardan en `/var/log/` o en tu home directory
- Usa rutas absolutas (no relativas)

## 📁 Estructura de Scripts Recomendada

```
scripts/
├── deploy.sh           # Despliegue automático
├── backup-nebula.sh    # Backup completo
└── setup-cron.sh       # Configurador interactivo (opcional)
```
