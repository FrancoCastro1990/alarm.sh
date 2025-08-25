# Alarm System 🔔

Una herramienta completa de gestión de alarmas para la línea de comandos que permite crear alarmas instantáneas, programar alarmas recurrentes y configurar temporizadores relativos. Todas las alarmas muestran notificaciones de escritorio y reproducen alertas de sonido.

## Características

- ⏰ **Alarmas instantáneas**: Establece alarmas para una hora específica del día
- ⏱️ **Temporizadores**: Crea alarmas después de un tiempo específico (MM:SS)
- ⚡ **Temporizadores inteligentes**: Usa `sleep` para alta precisión (≤3min) o `cron` para duraciones largas
- 🎛️ **Umbral configurable**: Personaliza cuándo usar `sleep` vs `cron` con `--tempo-threshold`
- 📅 **Alarmas programadas**: Configura alarmas recurrentes para días específicos
- 🔇 **Modo silencioso**: Opción para desactivar el sonido
- 📋 **Gestión completa**: Lista, elimina y borra todas las alarmas
- 🔔 **Notificaciones**: Notificaciones de escritorio automáticas
- 🎵 **Alertas de sonido**: Múltiples formatos de audio soportados

## Dependencias

### Requisitos del sistema
- **Bash**: Shell compatible (viene preinstalado en la mayoría de distribuciones Linux)
- **cron**: Para programar alarmas (generalmente preinstalado)
- **notify-send**: Para notificaciones de escritorio
- **Audio system**: PulseAudio o ALSA para reproducir sonidos

### Instalación de dependencias

**Ubuntu/Debian:**
```bash
sudo apt update
sudo apt install libnotify-bin pulseaudio-utils alsa-utils
```

**Fedora/RHEL/CentOS:**
```bash
sudo dnf install libnotify pulseaudio-utils alsa-utils
```

**Arch Linux:**
```bash
sudo pacman -S libnotify pulseaudio alsa-utils
```

## Instalación

### Instalación rápida con una línea 🚀

```bash
curl -fsSL https://raw.githubusercontent.com/FrancoCastro1990/alarm.sh/refs/heads/main/install.sh | bash
```

> **💡 Tip:** Este comando descarga y ejecuta automáticamente el instalador, detecta tu sistema operativo, instala todas las dependencias y configura la herramienta. ¡Listo en segundos!

> **🔒 Seguridad:** Si prefieres revisar el código antes de ejecutar, puedes ver el script de instalación [aquí](https://github.com/FrancoCastro1990/alarm.sh/blob/main/install.sh) o usar la instalación manual.

### Instalación automática (Alternativa) 📥

1. **Clona el repositorio:**
```bash
git clone https://github.com/FrancoCastro1990/alarm.sh.git
cd alarm.sh
```

2. **Ejecuta el script de instalación:**
```bash
./install.sh
```

El script de instalación automáticamente:
- ✅ Detecta tu distribución Linux (Ubuntu, Debian, Fedora, Arch, etc.)
- ✅ Instala todas las dependencias necesarias
- ✅ Configura y verifica el servicio cron
- ✅ Hace el script ejecutable
- ✅ Opcionalmente instala el comando globalmente
- ✅ Verifica que todo funcione correctamente

### Instalación manual

Si prefieres instalar manualmente o el script automático no funciona en tu sistema:

1. **Clona o descarga el script:**
```bash
git clone https://github.com/FrancoCastro1990/alarm.sh.git
cd alarm.sh
```

2. **Instala las dependencias según tu distribución:**
   - **Ubuntu/Debian:** `sudo apt update && sudo apt install libnotify-bin pulseaudio-utils alsa-utils`
   - **Fedora/RHEL:** `sudo dnf install libnotify pulseaudio-utils alsa-utils`
   - **Arch Linux:** `sudo pacman -S libnotify pulseaudio alsa-utils`

3. **Haz el script ejecutable:**
```bash
chmod +x alarm.sh
```

4. **Opcionalmente, instala globalmente:**
```bash
sudo cp alarm.sh /usr/local/bin/alarm
```

5. **Verifica que cron esté ejecutándose:**
```bash
sudo systemctl status cron
# o en sistemas con systemd:
sudo systemctl status cronie
```

## Uso

### Sintaxis básica

```bash
# Alarma para una hora específica
alarm HH:MM [-m "mensaje"] [--no-sound]

# Temporizador (alarma después de MM:SS)
alarm --tempo MM:SS [-m "mensaje"] [--no-sound] [--tempo-threshold SEGUNDOS]

# Alarma programada (recurrente)
alarm --schedule HH:MM -m "mensaje" --days DÍAS [--no-sound]

# Gestión de alarmas
alarm --list
alarm --remove ID
alarm --clear-all
```

### Ejemplos prácticos

#### Alarmas instantáneas
```bash
# Alarma para las 2:30 PM
alarm 14:30

# Alarma con mensaje personalizado
alarm 09:00 -m "Reunión importante"

# Alarma silenciosa
alarm 16:45 -m "Fin del día laboral" --no-sound
```

#### Temporizadores
```bash
# Temporizador de 5 minutos (usa cron por defecto, >3min)
alarm --tempo 05:00

# Temporizador de 25 minutos para técnica Pomodoro
alarm --tempo 25:00 -m "Descanso Pomodoro"

# Temporizador corto de 2 minutos (usa sleep, alta precisión)
alarm --tempo 02:00 -m "Timer rápido"

# Forzar uso de sleep para temporizador de 5 minutos
alarm --tempo 05:00 --tempo-threshold 600 -m "Sleep hasta 10 minutos"

# Forzar uso de cron para temporizador de 1 minuto
alarm --tempo 01:00 --tempo-threshold 30 -m "Cron para >30 segundos"

# Temporizador silencioso de 1 hora y 30 minutos
alarm --tempo 90:00 -m "Reunión terminada" --no-sound
```

#### Alarmas programadas (recurrentes)
```bash
# Alarma diaria a las 9:00 AM
alarm --schedule 09:00 -m "Daily Standup" --days daily

# Alarma de lunes a viernes
alarm --schedule 08:00 -m "Hora de trabajar" --days weekdays

# Alarma de fin de semana
alarm --schedule 10:00 -m "Desayuno relajado" --days weekend

# Días específicos
alarm --schedule 18:00 -m "Gimnasio" --days monday,wednesday,friday

# Un día específico
alarm --schedule 20:00 -m "Serie favorita" --days friday
```

#### Gestión de alarmas
```bash
# Listar todas las alarmas configuradas
alarm --list

# Eliminar alarma específica (usar ID de la lista)
alarm --remove 1

# Eliminar todas las alarmas
alarm --clear-all
```

### Días válidos para alarmas programadas

- **Grupos de días**: `daily`, `weekdays`, `weekend`
- **Días individuales**: `monday`, `tuesday`, `wednesday`, `thursday`, `friday`, `saturday`, `sunday`
- **Combinaciones**: `monday,friday`, `tuesday,thursday`, etc.

### Opciones disponibles

| Opción | Descripción |
|--------|-------------|
| `-m, --message` | Mensaje personalizado para la alarma |
| `--no-sound` | Desactiva el sonido de la alarma |
| `--tempo` | Modo temporizador (MM:SS) |
| `--tempo-threshold SEGUNDOS` | Umbral para usar `sleep` vs `cron` (por defecto: 180 segundos/3 minutos) |
| `--schedule` | Programa alarma recurrente |
| `--days` | Especifica días para alarmas programadas |
| `--list` | Lista todas las alarmas configuradas |
| `--remove ID` | Elimina alarma específica por ID |
| `--clear-all` | Elimina todas las alarmas |
| `-h, --help` | Muestra ayuda detallada |

## Archivos de sonido

El script busca automáticamente archivos de sonido en el siguiente orden:
1. `/usr/share/sounds/freedesktop/stereo/alarm-clock-elapsed.oga`
2. `/usr/share/sounds/alsa/Front_Left.wav`
3. `/usr/share/sounds/sound-icons/prompt.wav`
4. `/usr/share/sounds/ubuntu/stereo/bell.ogg`

Si no encuentra ningún archivo, usa el pitido del sistema como respaldo.

## Sistema de Temporizadores Inteligente

El sistema utiliza dos métodos diferentes para manejar temporizadores según su duración:

### 🚀 **Sleep (Alta Precisión)**
- **Cuándo**: Para temporizadores ≤ umbral (por defecto 180 segundos/3 minutos)
- **Ventajas**: Precisión al segundo, ejecución instantánea
- **Limitación**: El proceso debe mantenerse en ejecución

### ⏰ **Cron (Persistente)**
- **Cuándo**: Para temporizadores > umbral
- **Ventajas**: Persiste aunque cierres la terminal, manejo de temporizadores largos
- **Limitación**: Precisión al minuto (los segundos se redondean)

### ⚙️ **Configuración del Umbral**

```bash
# Usar sleep para temporizadores ≤ 60 segundos
alarm --tempo 02:00 --tempo-threshold 60

# Usar sleep para temporizadores ≤ 10 minutos  
alarm --tempo 05:00 --tempo-threshold 600

# Valor por defecto (180 segundos = 3 minutos)
alarm --tempo 02:30  # Usa sleep (≤3min)
alarm --tempo 05:00  # Usa cron (>3min)
```

## Solución de problemas

### Las notificaciones no aparecen
- Verifica que `notify-send` esté instalado
- Asegúrate de que tu entorno de escritorio soporte notificaciones

### No se reproduce sonido
- Verifica que PulseAudio o ALSA estén funcionando
- Comprueba que existan archivos de sonido en las rutas especificadas
- Prueba reproducir sonido manualmente: `paplay /usr/share/sounds/alsa/Front_Left.wav`

### Las alarmas programadas no funcionan
- Verifica que cron esté ejecutándose: `sudo systemctl status cron`
- Comprueba que el script tenga permisos de ejecución
- Revisa los logs de cron: `sudo tail -f /var/log/cron`

## Limitaciones

- Requiere que el sistema esté encendido para que las alarmas funcionen
- Las alarmas programadas dependen del servicio cron
- Las notificaciones requieren un entorno de escritorio activo

## Contribuciones

Las contribuciones son bienvenidas. Por favor:
1. Fork el proyecto
2. Crea una rama para tu feature (`git checkout -b feature/nueva-funcionalidad`)
3. Commit tus cambios (`git commit -am 'Agrega nueva funcionalidad'`)
4. Push a la rama (`git push origin feature/nueva-funcionalidad`)
5. Abre un Pull Request

## Licencia

Este proyecto está bajo la Licencia MIT. Ver el archivo `LICENSE` para más detalles.

## Autor

**Franco Castro**

---

*¿Encontraste útil esta herramienta? ¡Dale una estrella al repositorio! ⭐*