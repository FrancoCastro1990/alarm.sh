#!/bin/bash

# Alarm System - Script de Instalación Automática
# Autor: Franco Castro
# Descripción: Instala automáticamente las dependencias y configura Alarm System

set -e  # Salir si hay algún error

# Colores para output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
CYAN='\033[0;36m'
NC='\033[0m' # No Color

# Función para imprimir mensajes con colores
print_info() {
    echo -e "${BLUE}ℹ️  $1${NC}"
}

print_success() {
    echo -e "${GREEN}✅ $1${NC}"
}

print_warning() {
    echo -e "${YELLOW}⚠️  $1${NC}"
}

print_error() {
    echo -e "${RED}❌ $1${NC}"
}

print_header() {
    echo -e "${CYAN}🔔 $1${NC}"
}

# Función para detectar la distribución
detect_distro() {
    if [[ -f /etc/os-release ]]; then
        . /etc/os-release
        echo "$ID"
    elif type lsb_release >/dev/null 2>&1; then
        lsb_release -si | tr '[:upper:]' '[:lower:]'
    elif [[ -f /etc/redhat-release ]]; then
        echo "rhel"
    else
        echo "unknown"
    fi
}

# Función para verificar si un comando existe
command_exists() {
    command -v "$1" >/dev/null 2>&1
}

# Función para verificar si un paquete está instalado
package_installed() {
    case "$DISTRO" in
        ubuntu|debian)
            dpkg -l "$1" >/dev/null 2>&1
            ;;
        fedora|rhel|centos)
            rpm -q "$1" >/dev/null 2>&1
            ;;
        arch|manjaro)
            pacman -Q "$1" >/dev/null 2>&1
            ;;
        *)
            return 1
            ;;
    esac
}

# Función para detectar sistema de audio disponible
detect_audio_system() {
    if command -v pw-play >/dev/null 2>&1; then
        echo "pipewire"
    elif command -v paplay >/dev/null 2>&1; then
        echo "pulseaudio"
    elif command -v aplay >/dev/null 2>&1; then
        echo "alsa"
    else
        echo "none"
    fi
}

# Función para instalar dependencias según la distribución
install_dependencies() {
    local packages_to_install=()
    local audio_packages=()
    
    print_info "Verificando dependencias..."
    
    # Detectar sistema de audio actual
    local current_audio=$(detect_audio_system)
    print_info "Sistema de audio detectado: $current_audio"
    
    case "$DISTRO" in
        ubuntu|debian)
            # Verificar qué paquetes faltan
            ! package_installed "libnotify-bin" && packages_to_install+=("libnotify-bin")
            ! package_installed "alsa-utils" && packages_to_install+=("alsa-utils")
            
            # Instalar dependencias de audio según disponibilidad
            if [[ "$current_audio" == "pipewire" ]] || package_installed "pipewire"; then
                ! package_installed "pipewire-pulse" && audio_packages+=("pipewire-pulse")
                ! package_installed "pipewire-audio" && audio_packages+=("pipewire-audio")
                print_info "PipeWire detectado - instalando compatibilidad PulseAudio"
            elif [[ "$current_audio" == "pulseaudio" ]] || package_installed "pulseaudio"; then
                ! package_installed "pulseaudio-utils" && audio_packages+=("pulseaudio-utils")
                print_info "PulseAudio detectado - instalando utilidades"
            else
                # Si no hay ninguno, intentar PipeWire primero (más moderno)
                print_info "No se detectó sistema de audio - instalando PipeWire"
                ! package_installed "pipewire" && audio_packages+=("pipewire")
                ! package_installed "pipewire-pulse" && audio_packages+=("pipewire-pulse")
                ! package_installed "pipewire-audio" && audio_packages+=("pipewire-audio")
            fi
            
            packages_to_install+=("${audio_packages[@]}")
            
            if [[ ${#packages_to_install[@]} -gt 0 ]]; then
                print_info "Actualizando lista de paquetes..."
                sudo apt update
                
                print_info "Instalando dependencias: ${packages_to_install[*]}"
                sudo apt install -y "${packages_to_install[@]}"
            fi
            ;;
            
        fedora|rhel|centos)
            ! package_installed "libnotify" && packages_to_install+=("libnotify")
            ! package_installed "alsa-utils" && packages_to_install+=("alsa-utils")
            
            # Instalar dependencias de audio según disponibilidad
            if [[ "$current_audio" == "pipewire" ]] || package_installed "pipewire"; then
                ! package_installed "pipewire-pulseaudio" && audio_packages+=("pipewire-pulseaudio")
                print_info "PipeWire detectado - instalando compatibilidad PulseAudio"
            elif [[ "$current_audio" == "pulseaudio" ]] || package_installed "pulseaudio"; then
                ! package_installed "pulseaudio-utils" && audio_packages+=("pulseaudio-utils")
                print_info "PulseAudio detectado - instalando utilidades"
            else
                # Si no hay ninguno, intentar PipeWire primero
                print_info "No se detectó sistema de audio - instalando PipeWire"
                ! package_installed "pipewire" && audio_packages+=("pipewire")
                ! package_installed "pipewire-pulseaudio" && audio_packages+=("pipewire-pulseaudio")
            fi
            
            packages_to_install+=("${audio_packages[@]}")
            
            if [[ ${#packages_to_install[@]} -gt 0 ]]; then
                print_info "Instalando dependencias: ${packages_to_install[*]}"
                sudo dnf install -y "${packages_to_install[@]}"
            fi
            ;;
            
        arch|manjaro)
            ! package_installed "libnotify" && packages_to_install+=("libnotify")
            ! package_installed "alsa-utils" && packages_to_install+=("alsa-utils")
            
            # Instalar dependencias de audio según disponibilidad
            if [[ "$current_audio" == "pipewire" ]] || package_installed "pipewire"; then
                ! package_installed "pipewire-pulse" && audio_packages+=("pipewire-pulse")
                print_info "PipeWire detectado - instalando compatibilidad PulseAudio"
            elif [[ "$current_audio" == "pulseaudio" ]] || package_installed "pulseaudio"; then
                # PulseAudio ya incluye las utilidades en Arch
                print_info "PulseAudio detectado"
            else
                # Si no hay ninguno, intentar PipeWire primero
                print_info "No se detectó sistema de audio - instalando PipeWire"
                ! package_installed "pipewire" && audio_packages+=("pipewire")
                ! package_installed "pipewire-pulse" && audio_packages+=("pipewire-pulse")
            fi
            
            packages_to_install+=("${audio_packages[@]}")
            
            if [[ ${#packages_to_install[@]} -gt 0 ]]; then
                print_info "Instalando dependencias: ${packages_to_install[*]}"
                sudo pacman -S --noconfirm "${packages_to_install[@]}"
            fi
            ;;
            
        *)
            print_error "Distribución no soportada: $DISTRO"
            print_info "Distribuciones soportadas: Ubuntu, Debian, Fedora, RHEL, CentOS, Arch Linux, Manjaro"
            print_info "Por favor, instala manualmente las dependencias:"
            print_info "- libnotify (notify-send)"
            print_info "- pipewire + pipewire-pulse (recomendado) o pulseaudio-utils"
            print_info "- alsa-utils"
            return 1
            ;;
    esac
    
    if [[ ${#packages_to_install[@]} -eq 0 ]]; then
        print_success "Todas las dependencias ya están instaladas"
    else
        print_success "Dependencias instaladas correctamente"
    fi
}

# Función para detectar si cron está disponible
has_cron() {
    # Verificar si crontab existe
    if command_exists "crontab"; then
        return 0
    fi
    
    # Verificar si el servicio cron existe
    if systemctl list-unit-files | grep -q "^cron.service\|^cronie.service" 2>/dev/null; then
        return 0
    fi
    
    return 1
}

# Función para detectar si systemd está disponible
has_systemd() {
    if command_exists "systemctl" && systemctl --version >/dev/null 2>&1; then
        return 0
    fi
    return 1
}

# Función para determinar qué versión instalar
select_version() {
    print_info "Detectando sistema de scheduling disponible..."
    
    local has_cron_system=false
    local has_systemd_system=false
    
    if has_systemd; then
        has_systemd_system=true
        local systemd_version=$(systemctl --version | head -1 | awk '{print $2}')
        print_success "✓ systemd detectado (versión $systemd_version)"
    else
        print_warning "✗ systemd no disponible"
    fi
    
    if has_cron; then
        has_cron_system=true
        print_success "✓ cron detectado"
    else
        print_warning "✗ cron no disponible"
    fi
    
    echo
    
    # Validar que al menos uno esté disponible
    if [[ "$has_cron_system" == false ]] && [[ "$has_systemd_system" == false ]]; then
        print_error "❌ Sistema incompatible"
        echo
        print_error "No se detectó ni systemd ni cron en este sistema"
        print_info "alarm.sh requiere al menos uno de los siguientes:"
        print_info "  • systemd (systemctl) - para alarm-v2.sh (recomendado)"
        print_info "  • cron (crontab) - para alarm.sh"
        echo
        print_info "Por favor, instala uno de estos sistemas:"
        echo
        case "$DISTRO" in
            ubuntu|debian)
                print_info "  Para systemd: sudo apt install systemd"
                print_info "  Para cron:    sudo apt install cron"
                ;;
            fedora|rhel|centos)
                print_info "  Para systemd: sudo dnf install systemd"
                print_info "  Para cron:    sudo dnf install cronie"
                ;;
            arch|manjaro)
                print_info "  Para systemd: sudo pacman -S systemd"
                print_info "  Para cron:    sudo pacman -S cronie"
                ;;
            *)
                print_info "  Instala systemd o cron según tu distribución"
                ;;
        esac
        echo
        return 1
    fi
    
    # Decidir qué versión instalar (prioridad: systemd > cron)
    if [[ "$has_systemd_system" == true ]]; then
        if [[ "$has_cron_system" == true ]]; then
            print_info "Ambos sistemas disponibles: systemd y cron"
            print_info "Se recomienda usar la versión systemd (más moderna y precisa)"
            echo
            read -p "¿Qué versión deseas instalar? [1=systemd, 2=cron] (default: 1): " -n 1 -r
            echo
            
            if [[ $REPLY == "2" ]]; then
                ALARM_VERSION="cron"
                ALARM_SCRIPT="alarm.sh"
                print_success "Seleccionada: alarm.sh (versión cron)"
            else
                ALARM_VERSION="systemd"
                ALARM_SCRIPT="alarm-v2.sh"
                print_success "Seleccionada: alarm-v2.sh (versión systemd)"
            fi
        else
            print_info "Solo systemd disponible - instalando alarm-v2.sh"
            ALARM_VERSION="systemd"
            ALARM_SCRIPT="alarm-v2.sh"
        fi
    elif [[ "$has_cron_system" == true ]]; then
        print_info "Solo cron disponible - instalando alarm.sh"
        ALARM_VERSION="cron"
        ALARM_SCRIPT="alarm.sh"
    fi
    
    echo
    print_info "Versión seleccionada: $ALARM_SCRIPT"
    return 0
}

# Función para verificar servicios según la versión
check_services() {
    if [[ "$ALARM_VERSION" == "cron" ]]; then
        print_info "Verificando servicio cron..."
        
        # Verificar cron
        if systemctl is-active --quiet cron 2>/dev/null; then
            print_success "Servicio cron está activo"
        elif systemctl is-active --quiet cronie 2>/dev/null; then
            print_success "Servicio cronie está activo"
        else
            print_warning "Servicio cron no está activo"
            print_info "Intentando iniciar servicio cron..."
            
            if systemctl list-unit-files | grep -q "^cron.service"; then
                sudo systemctl enable --now cron
            elif systemctl list-unit-files | grep -q "^cronie.service"; then
                sudo systemctl enable --now cronie
            else
                print_error "No se encontró servicio cron en el sistema"
                return 1
            fi
            
            print_success "Servicio cron iniciado y habilitado"
        fi
    else
        print_info "Verificando systemd..."
        if has_systemd; then
            print_success "systemd está disponible y funcionando"
        else
            print_error "systemd no está disponible"
            return 1
        fi
    fi
}

# Función para descargar scripts si no existen
download_alarm_script() {
    local script_to_download="$1"
    
    if [[ ! -f "$script_to_download" ]]; then
        print_info "Descargando $script_to_download desde GitHub..."
        
        if command_exists "curl"; then
            curl -fsSL -o "$script_to_download" "https://raw.githubusercontent.com/FrancoCastro1990/alarm.sh/refs/heads/main/$script_to_download"
        elif command_exists "wget"; then
            wget -q -O "$script_to_download" "https://raw.githubusercontent.com/FrancoCastro1990/alarm.sh/refs/heads/main/$script_to_download"
        else
            print_error "Se requiere curl o wget para descargar el script"
            print_info "Por favor instala curl: sudo apt install curl (Ubuntu/Debian)"
            print_info "O clona el repositorio manualmente: git clone https://github.com/FrancoCastro1990/alarm.sh.git"
            return 1
        fi
        
        if [[ -f "$script_to_download" ]]; then
            print_success "$script_to_download descargado correctamente"
        else
            print_error "Error descargando $script_to_download"
            return 1
        fi
    fi
}

# Función para configurar el script
setup_script() {
    print_info "Configurando $ALARM_SCRIPT..."
    
    # Descargar el script seleccionado si no existe
    if ! download_alarm_script "$ALARM_SCRIPT"; then
        return 1
    fi
    
    # Verificar que el script existe
    if [[ ! -f "$ALARM_SCRIPT" ]]; then
        print_error "No se encontró el archivo $ALARM_SCRIPT"
        print_info "Asegúrate de ejecutar este script desde el directorio que contiene $ALARM_SCRIPT"
        print_info "O usa la instalación con curl: curl -fsSL https://raw.githubusercontent.com/FrancoCastro1990/alarm.sh/refs/heads/main/install.sh | bash"
        return 1
    fi
    
    # Hacer ejecutable
    chmod +x "$ALARM_SCRIPT"
    print_success "Permisos de ejecución establecidos para $ALARM_SCRIPT"
    
    # Preguntar si quiere instalación global
    echo
    print_info "¿Deseas instalar alarm de forma global? (recomendado)"
    print_info "Esto copiará el script a /usr/local/bin/alarm para usarlo desde cualquier directorio"
    read -p "¿Continuar? [Y/n]: " -n 1 -r
    echo
    
    if [[ $REPLY =~ ^[Yy]$ ]] || [[ -z $REPLY ]]; then
        sudo cp "$ALARM_SCRIPT" /usr/local/bin/alarm
        print_success "Script instalado globalmente como 'alarm' ($ALARM_SCRIPT)"
        print_info "Ahora puedes usar 'alarm' desde cualquier directorio"
        
        # Mostrar info sobre la versión instalada
        echo
        if [[ "$ALARM_VERSION" == "systemd" ]]; then
            print_info "📌 Versión instalada: systemd (alarm-v2.sh)"
            print_info "   - Precisión de segundos"
            print_info "   - No requiere cron"
            print_info "   - Compatible con systemd timers"
        else
            print_info "📌 Versión instalada: cron (alarm.sh)"
            print_info "   - Precisión de minutos"
            print_info "   - Requiere servicio cron activo"
            print_info "   - Compatible con sistemas tradicionales"
        fi
    else
        print_info "Script configurado localmente. Usa './$ALARM_SCRIPT' para ejecutar"
    fi
}

# Función para verificar la instalación
verify_installation() {
    print_info "Verificando instalación..."
    
    # Verificar comandos básicos
    local missing_commands=()
    
    ! command_exists "notify-send" && missing_commands+=("notify-send")
    
    # Solo verificar crontab si estamos usando la versión cron
    if [[ "$ALARM_VERSION" == "cron" ]]; then
        ! command_exists "crontab" && missing_commands+=("crontab")
    fi
    
    if [[ ${#missing_commands[@]} -gt 0 ]]; then
        print_error "Comandos faltantes: ${missing_commands[*]}"
        return 1
    fi
    
    # Verificar audio
    local audio_system=$(detect_audio_system)
    case "$audio_system" in
        "pipewire")
            print_success "PipeWire detectado (pw-play disponible)"
            if command_exists "paplay"; then
                print_success "Compatibilidad PulseAudio disponible (paplay disponible)"
            fi
            ;;
        "pulseaudio")
            print_success "PulseAudio detectado (paplay disponible)"
            ;;
        "alsa")
            print_success "ALSA detectado (aplay disponible)"
            print_warning "Solo archivos .wav serán reproducibles"
            ;;
        "none")
            print_warning "No se detectó sistema de audio. Las alarmas usarán solo beep del sistema"
            ;;
    esac
    
    # Probar notificación
    if command_exists "notify-send"; then
        notify-send "Alarm System" "¡Instalación completada exitosamente! (versión: $ALARM_VERSION)" 2>/dev/null || true
        print_success "Sistema de notificaciones funcionando"
    fi
    
    print_success "Verificación completada"
}

# Función para mostrar ejemplos de uso
show_usage_examples() {
    print_header "¡Instalación completada! 🎉"
    echo
    
    if [[ "$ALARM_VERSION" == "systemd" ]]; then
        print_success "Versión instalada: alarm-v2.sh (systemd timers)"
        print_info "Ventajas: Precisión de segundos, mejor logging, no requiere cron"
    else
        print_success "Versión instalada: alarm.sh (cron)"
        print_info "Compatible con sistemas tradicionales Unix/Linux"
    fi
    
    echo
    print_info "Ejemplos de uso:"
    echo
    echo "  # Alarma para las 14:30"
    echo "  alarm 14:30 -m \"Reunión importante\""
    echo
    echo "  # Temporizador de 5 minutos"
    echo "  alarm --tempo 05:00 -m \"Descanso\""
    echo
    echo "  # Alarma programada de lunes a viernes"
    echo "  alarm --schedule 09:00 -m \"Daily standup\" --days weekdays"
    echo
    echo "  # Ver todas las alarmas"
    echo "  alarm --list"
    echo
    echo "  # Ayuda completa"
    echo "  alarm --help"
    echo
    
    if [[ "$ALARM_VERSION" == "systemd" ]]; then
        print_info "💡 Comandos adicionales de systemd:"
        echo "   systemctl --user list-timers    # Ver todos los timers de usuario"
        echo "   journalctl --user -u alarm-*    # Ver logs de las alarmas"
        echo
    fi
    
    print_info "Para más ejemplos, consulta: https://github.com/FrancoCastro1990/alarm.sh#readme"
    echo
    print_info "💡 Comparte este instalador:"
    echo "   curl -fsSL https://raw.githubusercontent.com/FrancoCastro1990/alarm.sh/refs/heads/main/install.sh | bash"
}

# Función principal
main() {
    clear
    print_header "=== Alarm System - Instalador Automático ==="
    print_header "Autor: Franco Castro"
    echo
    
    # Verificar que se ejecuta como usuario normal (no root)
    if [[ $EUID -eq 0 ]]; then
        print_error "No ejecutes este script como root"
        print_info "El script necesita permisos sudo solo para instalar paquetes"
        exit 1
    fi
    
    # Detectar distribución
    DISTRO=$(detect_distro)
    print_info "Distribución detectada: $DISTRO"
    echo
    
    # Verificar conexión a internet
    if ! ping -c 1 8.8.8.8 >/dev/null 2>&1; then
        print_error "No hay conexión a internet. Se requiere para instalar dependencias"
        exit 1
    fi
    
    print_success "Conexión a internet verificada"
    echo
    
    # Seleccionar versión según disponibilidad de cron/systemd
    if ! select_version; then
        exit 1
    fi
    echo
    
    # Instalar dependencias
    if ! install_dependencies; then
        print_error "Error instalando dependencias"
        exit 1
    fi
    echo
    
    # Verificar servicios según la versión
    if ! check_services; then
        print_error "Error configurando servicios"
        exit 1
    fi
    echo
    
    # Configurar script
    if ! setup_script; then
        print_error "Error configurando el script"
        exit 1
    fi
    echo
    
    # Verificar instalación
    if ! verify_installation; then
        print_error "Error en la verificación final"
        exit 1
    fi
    echo
    
    # Mostrar ejemplos
    show_usage_examples
}

# Ejecutar función principal
main "$@"