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

# Función para instalar dependencias según la distribución
install_dependencies() {
    local packages_to_install=()
    
    print_info "Verificando dependencias..."
    
    case "$DISTRO" in
        ubuntu|debian)
            # Verificar qué paquetes faltan
            ! package_installed "libnotify-bin" && packages_to_install+=("libnotify-bin")
            ! package_installed "pulseaudio-utils" && packages_to_install+=("pulseaudio-utils")
            ! package_installed "alsa-utils" && packages_to_install+=("alsa-utils")
            
            if [[ ${#packages_to_install[@]} -gt 0 ]]; then
                print_info "Actualizando lista de paquetes..."
                sudo apt update
                
                print_info "Instalando dependencias: ${packages_to_install[*]}"
                sudo apt install -y "${packages_to_install[@]}"
            fi
            ;;
            
        fedora|rhel|centos)
            ! package_installed "libnotify" && packages_to_install+=("libnotify")
            ! package_installed "pulseaudio-utils" && packages_to_install+=("pulseaudio-utils")
            ! package_installed "alsa-utils" && packages_to_install+=("alsa-utils")
            
            if [[ ${#packages_to_install[@]} -gt 0 ]]; then
                print_info "Instalando dependencias: ${packages_to_install[*]}"
                sudo dnf install -y "${packages_to_install[@]}"
            fi
            ;;
            
        arch|manjaro)
            ! package_installed "libnotify" && packages_to_install+=("libnotify")
            ! package_installed "pulseaudio" && packages_to_install+=("pulseaudio")
            ! package_installed "alsa-utils" && packages_to_install+=("alsa-utils")
            
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
            print_info "- pulseaudio-utils"
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

# Función para verificar servicios
check_services() {
    print_info "Verificando servicios del sistema..."
    
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
}

# Función para descargar alarm.sh si no existe
download_alarm_script() {
    if [[ ! -f "alarm.sh" ]]; then
        print_info "Descargando alarm.sh desde GitHub..."
        
        if command_exists "curl"; then
            curl -fsSL -o alarm.sh https://raw.githubusercontent.com/FrancoCastro1990/alarm.sh/refs/heads/main/alarm.sh
        elif command_exists "wget"; then
            wget -q -O alarm.sh https://raw.githubusercontent.com/FrancoCastro1990/alarm.sh/refs/heads/main/alarm.sh
        else
            print_error "Se requiere curl o wget para descargar el script"
            print_info "Por favor instala curl: sudo apt install curl (Ubuntu/Debian)"
            print_info "O clona el repositorio manualmente: git clone https://github.com/FrancoCastro1990/alarm.sh.git"
            return 1
        fi
        
        if [[ -f "alarm.sh" ]]; then
            print_success "alarm.sh descargado correctamente"
        else
            print_error "Error descargando alarm.sh"
            return 1
        fi
    fi
}

# Función para configurar el script
setup_script() {
    print_info "Configurando alarm.sh..."
    
    # Descargar alarm.sh si no existe (para instalación directa con curl)
    if ! download_alarm_script; then
        return 1
    fi
    
    # Verificar que alarm.sh existe
    if [[ ! -f "alarm.sh" ]]; then
        print_error "No se encontró el archivo alarm.sh"
        print_info "Asegúrate de ejecutar este script desde el directorio que contiene alarm.sh"
        print_info "O usa la instalación con curl: curl -fsSL https://raw.githubusercontent.com/FrancoCastro1990/alarm.sh/refs/heads/main/install.sh | bash"
        return 1
    fi
    
    # Hacer ejecutable
    chmod +x alarm.sh
    print_success "Permisos de ejecución establecidos para alarm.sh"
    
    # Preguntar si quiere instalación global
    echo
    print_info "¿Deseas instalar alarm de forma global? (recomendado)"
    print_info "Esto copiará el script a /usr/local/bin/alarm para usarlo desde cualquier directorio"
    read -p "¿Continuar? [Y/n]: " -n 1 -r
    echo
    
    if [[ $REPLY =~ ^[Yy]$ ]] || [[ -z $REPLY ]]; then
        sudo cp alarm.sh /usr/local/bin/alarm
        print_success "Script instalado globalmente como 'alarm'"
        print_info "Ahora puedes usar 'alarm' desde cualquier directorio"
    else
        print_info "Script configurado localmente. Usa './alarm.sh' para ejecutar"
    fi
}

# Función para verificar la instalación
verify_installation() {
    print_info "Verificando instalación..."
    
    # Verificar comandos básicos
    local missing_commands=()
    
    ! command_exists "notify-send" && missing_commands+=("notify-send")
    ! command_exists "crontab" && missing_commands+=("crontab")
    
    if [[ ${#missing_commands[@]} -gt 0 ]]; then
        print_error "Comandos faltantes: ${missing_commands[*]}"
        return 1
    fi
    
    # Verificar audio
    if command_exists "paplay"; then
        print_success "PulseAudio detectado (paplay disponible)"
    elif command_exists "aplay"; then
        print_success "ALSA detectado (aplay disponible)"
    else
        print_warning "No se detectó sistema de audio. Las alarmas serán silenciosas por defecto"
    fi
    
    # Probar notificación
    if command_exists "notify-send"; then
        notify-send "Alarm System" "¡Instalación completada exitosamente!" 2>/dev/null || true
        print_success "Sistema de notificaciones funcionando"
    fi
    
    print_success "Verificación completada"
}

# Función para mostrar ejemplos de uso
show_usage_examples() {
    print_header "¡Instalación completada! 🎉"
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
    
    # Instalar dependencias
    if ! install_dependencies; then
        print_error "Error instalando dependencias"
        exit 1
    fi
    echo
    
    # Verificar servicios
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