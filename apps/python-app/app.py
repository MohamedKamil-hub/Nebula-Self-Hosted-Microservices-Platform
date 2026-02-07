from flask import Flask, render_template_string
import subprocess
import os

app = Flask(__name__)

HTML_TEMPLATE = '''
<!DOCTYPE html>
<html lang="es">
<head>
    <meta charset="UTF-8">
    <meta name="viewport" content="width=device-width, initial-scale=1.0">
    <title>Nebula PaaS - Panel de Control</title>
    <style>
        * {
            margin: 0;
            padding: 0;
            box-sizing: border-box;
        }
        
        body {
            font-family: 'Segoe UI', Tahoma, Geneva, Verdana, sans-serif;
            background: linear-gradient(135deg, #667eea 0%, #764ba2 100%);
            min-height: 100vh;
            display: flex;
            justify-content: center;
            align-items: center;
            padding: 20px;
        }
        
        .container {
            background: white;
            border-radius: 20px;
            padding: 40px;
            box-shadow: 0 20px 60px rgba(0,0,0,0.3);
            max-width: 800px;
            width: 100%;
        }
        
        h1 {
            color: #667eea;
            text-align: center;
            margin-bottom: 10px;
            font-size: 2.5em;
        }
        
        .subtitle {
            text-align: center;
            color: #666;
            margin-bottom: 40px;
            font-size: 1.1em;
        }
        
        .button-grid {
            display: grid;
            grid-template-columns: repeat(auto-fit, minmax(250px, 1fr));
            gap: 20px;
            margin-bottom: 30px;
        }
        
        .nav-button {
            background: linear-gradient(135deg, #667eea 0%, #764ba2 100%);
            color: white;
            padding: 25px;
            border: none;
            border-radius: 15px;
            font-size: 1.1em;
            font-weight: 600;
            cursor: pointer;
            transition: all 0.3s ease;
            text-decoration: none;
            display: flex;
            flex-direction: column;
            align-items: center;
            gap: 10px;
            box-shadow: 0 4px 15px rgba(102, 126, 234, 0.4);
        }
        
        .nav-button:hover {
            transform: translateY(-5px);
            box-shadow: 0 8px 25px rgba(102, 126, 234, 0.6);
        }
        
        .nav-button:active {
            transform: translateY(-2px);
        }
        
        .icon {
            font-size: 2em;
        }
        
        .backup-section {
            margin-top: 30px;
            padding-top: 30px;
            border-top: 2px solid #eee;
        }
        
        .backup-button {
            background: linear-gradient(135deg, #f093fb 0%, #f5576c 100%);
            width: 100%;
            padding: 20px;
            border: none;
            border-radius: 15px;
            color: white;
            font-size: 1.2em;
            font-weight: 600;
            cursor: pointer;
            transition: all 0.3s ease;
            box-shadow: 0 4px 15px rgba(245, 87, 108, 0.4);
        }
        
        .backup-button:hover {
            transform: translateY(-3px);
            box-shadow: 0 8px 25px rgba(245, 87, 108, 0.6);
        }
        
        .backup-button:active {
            transform: translateY(-1px);
        }
        
        .message {
            margin-top: 20px;
            padding: 15px;
            border-radius: 10px;
            text-align: center;
            font-weight: 500;
        }
        
        .success {
            background: #d4edda;
            color: #155724;
            border: 1px solid #c3e6cb;
        }
        
        .error {
            background: #f8d7da;
            color: #721c24;
            border: 1px solid #f5c6cb;
        }
        
        .footer {
            text-align: center;
            margin-top: 30px;
            color: #999;
            font-size: 0.9em;
        }
    </style>
</head>
<body>
    <div class="container">
        <h1>🌌 Nebula PaaS</h1>
        <p class="subtitle">Panel de Control - Acceso Rápido a Servicios</p>
        
        <div class="button-grid">
            <a href="https://app.nebula.test/" target="_blank" class="nav-button">
                <span class="icon">🏠</span>
                <span>Aplicación Principal</span>
            </a>
            
            <a href="https://wordpress.nebula.test/" target="_blank" class="nav-button">
                <span class="icon">📝</span>
                <span>WordPress</span>
            </a>
            
            <a href="http://localhost:81/nginx/proxy" target="_blank" class="nav-button">
                <span class="icon">🔧</span>
                <span>Nginx Proxy Manager</span>
            </a>
            
            <a href="http://localhost:19999/" target="_blank" class="nav-button">
                <span class="icon">📊</span>
                <span>NetData Monitor</span>
            </a>
        </div>
        
        <div class="backup-section">
            <form action="/backup" method="post" style="margin: 0;">
                <button type="submit" class="backup-button">
                    💾 Ejecutar Backup Completo
                </button>
            </form>
            
            {% if message %}
            <div class="message {{ message_type }}">
                {{ message }}
            </div>
            {% endif %}
        </div>
        
        <div class="footer">
            <p>Proyecto Intermodular - Nebula Self-Hosted PaaS</p>
            <p>Mohamed Kamil © 2026</p>
        </div>
    </div>
</body>
</html>
'''

@app.route('/')
def index():
    return render_template_string(HTML_TEMPLATE)

@app.route('/backup', methods=['POST'])
def backup():
    try:
        # Ruta al script de backup
        backup_script = os.path.expanduser('~/proyecto_intermodular/nebula-selfhosted-paas/scripts/backup-nebula.sh')
        
        # Verificar que el script existe
        if not os.path.exists(backup_script):
            return render_template_string(
                HTML_TEMPLATE, 
                message=f"Error: El script de backup no existe en {backup_script}",
                message_type="error"
            )
        
        # Ejecutar el script
        result = subprocess.run(
            ['bash', backup_script],
            capture_output=True,
            text=True,
            timeout=300  # 5 minutos de timeout
        )
        
        if result.returncode == 0:
            message = "✅ Backup completado exitosamente!"
            message_type = "success"
        else:
            message = f"❌ Error en el backup: {result.stderr[:200]}"
            message_type = "error"
            
    except subprocess.TimeoutExpired:
        message = "❌ Error: El backup tardó demasiado tiempo (timeout)"
        message_type = "error"
    except Exception as e:
        message = f"❌ Error al ejecutar backup: {str(e)}"
        message_type = "error"
    
    return render_template_string(
        HTML_TEMPLATE,
        message=message,
        message_type=message_type
    )

if __name__ == '__main__':
    app.run(host='0.0.0.0', port=5000, debug=True)
