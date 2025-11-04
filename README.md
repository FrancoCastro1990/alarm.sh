# Alarm System 🔔

Una herramienta completa de gestión de alarmas para la línea de comandos que permite crear alarmas instantáneas, programar alarmas recurrentes y configurar temporizadores relativos. Todas las alarmas muestran notificaciones de escritorio y reproducen alertas de sonido.

**Disponible en dos versiones:** Cron (tradicional) y systemd timers (moderna) - el instalador automático detecta tu sistema y elige la mejor opción.

## Características

- ⏰ **Alarmas instantáneas**: Establece alarmas para una hora específica del día
- ⏱️ **Temporizadores**: Crea alarmas después de un tiempo específico (MM:SS)
- ⚡ **Temporizadores inteligentes**: 
  - **Versión cron**: Usa `sleep` para alta precisión (≤3min) o `cron` para duraciones largas
  - **Versión systemd**: Usa `sleep` para alta precisión (≤3min) o `systemd timers` para duraciones largas (precisión de segundos)
- 🎛️ **Umbral configurable**: Personaliza cuándo usar `sleep` vs scheduling system con `--tempo-threshold`
- 📅 **Alarmas programadas**: Configura alarmas recurrentes para días específicos
- 🔇 **Modo silencioso**: Opción para desactivar el sonido
- 📋 **Gestión completa**: Lista, elimina y borra todas las alarmas
- 🔔 **Notificaciones**: Notificaciones de escritorio automáticas
- 🎵 **Alertas de sonido**: Múltiples formatos de audio soportados (PipeWire, PulseAudio, ALSA)
- 🔄 **Instalación inteligente**: Detecta automáticamente si usar cron o systemd

## Dependencias

### Requisitos del sistema

**Para versión cron (alarm.sh):**
- **Bash**: Shell compatible (viene preinstalado en la mayoría de distribuciones Linux)
- **cron**: Para programar alarmas (generalmente preinstalado)
- **notify-send**: Para notificaciones de escritorio
- **Audio system**: PipeWire, PulseAudio o ALSA para reproducir sonidos

**Para versión systemd (alarm-v2.sh):**
- **Bash**: Shell compatible
- **systemd**: Para gestionar timers (preinstalado en sistemas modernos)
- **notify-send**: Para notificaciones de escritorio
- **Audio system**: PipeWire, PulseAudio o ALSA para reproducir sonidos

> **💡 Nota:** El instalador automático detecta qué sistema tienes disponible (cron, systemd o ambos) y selecciona la versión apropiada.

### Instalación de dependencias

**Ubuntu/Debian:**
```bash
sudo apt update
sudo apt install libnotify-bin pipewire-pulse alsa-utils
# o para PulseAudio tradicional:
# sudo apt install libnotify-bin pulseaudio-utils alsa-utils
```

**Fedora/RHEL/CentOS:**
```bash
sudo dnf install libnotify pipewire-pulseaudio alsa-utils
# o para PulseAudio tradicional:
# sudo dnf install libnotify pulseaudio-utils alsa-utils
```

**Arch Linux:**
```bash
sudo pacman -S libnotify pipewire-pulse alsa-utils
# o para PulseAudio tradicional:
# sudo pacman -S libnotify pulseaudio alsa-utils
```

> **💡 Tip:** El instalador automático detecta tu sistema de audio (PipeWire o PulseAudio) e instala las dependencias correctas.

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
- ✅ Detecta si tienes cron, systemd o ambos
- ✅ Selecciona la versión apropiada (alarm.sh para cron o alarm-v2.sh para systemd)
- ✅ Detecta tu sistema de audio (PipeWire, PulseAudio o ALSA)
- ✅ Instala todas las dependencias necesarias según tu sistema
- ✅ Configura y verifica el servicio correspondiente (cron o systemd)
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

Para la versión con systemd:
```bash
sudo cp alarm-v2.sh /usr/local/bin/alarm
```

Para la versión con cron:
```bash
sudo cp alarm.sh /usr/local/bin/alarm
```

5. **Verifica que el servicio esté ejecutándose:**

Para systemd:
```bash
systemctl status systemd-logind  # Verifica que systemd esté activo
systemctl --user list-timers     # Lista los timers del usuario
```

Para cron:
```bash
sudo systemctl status cron
# o en sistemas con systemd:
sudo systemctl status cronie
```

## Uso

> **Nota:** `alarm.sh` (cron) y `alarm-v2.sh` (systemd) tienen la misma interfaz de comandos. Simplemente usa el script que instaló el instalador.

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
# Temporizador de 5 minutos
alarm --tempo 05:00

# Temporizador de 25 minutos para técnica Pomodoro
alarm --tempo 25:00 -m "Descanso Pomodoro"

# Temporizador corto de 2 minutos (usa sleep, alta precisión)
alarm --tempo 02:00 -m "Timer rápido"

# Forzar uso de sleep para temporizador de 5 minutos
alarm --tempo 05:00 --tempo-threshold 600 -m "Sleep hasta 10 minutos"

# Forzar uso del backend para temporizador de 1 minuto
# (cron en alarm.sh, systemd en alarm-v2.sh)
alarm --tempo 01:00 --tempo-threshold 30 -m "Backend para >30 segundos"

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
| `--tempo-threshold SEGUNDOS` | Umbral para usar `sleep` vs backend (por defecto: 180 segundos/3 minutos) |
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

### ⏰ **Backend Persistente (Cron o Systemd)**
- **Cuándo**: Para temporizadores > umbral
- **Ventajas**: Persiste aunque cierres la terminal, manejo de temporizadores largos
- **alarm.sh (cron)**: Precisión al minuto (los segundos se redondean)
- **alarm-v2.sh (systemd)**: Precisión al segundo

### ⚙️ **Configuración del Umbral**

```bash
# Usar sleep para temporizadores ≤ 60 segundos
alarm --tempo 02:00 --tempo-threshold 60

# Usar sleep para temporizadores ≤ 10 minutos  
alarm --tempo 05:00 --tempo-threshold 600

# Valor por defecto (180 segundos = 3 minutos)
alarm --tempo 02:30  # Usa sleep (≤3min)
alarm --tempo 05:00  # Usa backend persistente (>3min)
```

## Comparación de Versiones

| Característica | alarm.sh (cron) | alarm-v2.sh (systemd) |
|----------------|-----------------|----------------------|
| **Backend** | cron service | systemd timers |
| **Precisión alarmas** | Minuto | Segundo |
| **Precisión temporizadores** | Minuto (>umbral) | Segundo |
| **Persistencia** | ✅ Sí | ✅ Sí |
| **Requisitos** | cron instalado | systemd instalado |
| **Compatibilidad** | Todos los Unix | Linux moderno |
| **Gestión** | crontab -l | systemctl --user list-timers |
| **Logs** | /var/log/syslog | journalctl --user |

## Solución de problemas

### Las notificaciones no aparecen
- Verifica que `notify-send` esté instalado
- Asegúrate de que tu entorno de escritorio soporte notificaciones

### No se reproduce sonido
- Verifica que tu sistema de audio esté funcionando (PipeWire, PulseAudio o ALSA)
- Comprueba que existan archivos de sonido en las rutas especificadas
- Prueba reproducir sonido manualmente:
  - PipeWire: `pw-play /usr/share/sounds/alsa/Front_Left.wav`
  - PulseAudio: `paplay /usr/share/sounds/alsa/Front_Left.wav`
  - ALSA: `aplay /usr/share/sounds/alsa/Front_Left.wav`

### Las alarmas no se ejecutan (alarm.sh con cron)
- Verifica que el servicio cron esté ejecutándose: `sudo systemctl status cron` o `sudo systemctl status cronie`
- Comprueba tu crontab: `crontab -l`
- Revisa los logs del sistema: `grep CRON /var/log/syslog`

### Las alarmas no se ejecutan (alarm-v2.sh con systemd)
- Verifica tus timers de usuario: `systemctl --user list-timers`
- Comprueba el estado de un timer específico: `systemctl --user status alarm-ID.timer`
- Revisa los logs: `journalctl --user -u alarm-ID.service`
- Verifica que systemd user timers estén habilitados: `loginctl show-user $USER`

### Las alarmas programadas no funcionan

**Para alarm.sh (cron):**
- Verifica que cron esté ejecutándose: `sudo systemctl status cron`
- Comprueba que el script tenga permisos de ejecución
- Revisa los logs de cron: `sudo tail -f /var/log/cron`
- Verifica tu zona horaria: `date`
- Asegúrate de que el formato de hora sea correcto (HH:MM en formato 24 horas)

**Para alarm-v2.sh (systemd):**
- Lista tus timers activos: `systemctl --user list-timers --all`
- Verifica el calendario del timer: `systemctl --user cat alarm-ID.timer`
- Prueba manualmente el servicio: `systemctl --user start alarm-ID.service`
- Revisa que los días especificados sean válidos

## Limitaciones

- Requiere que el sistema esté encendido para que las alarmas funcionen
- **alarm.sh**: Las alarmas programadas dependen del servicio cron (precisión de minuto)
- **alarm-v2.sh**: Las alarmas programadas dependen de systemd timers (precisión de segundo)
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