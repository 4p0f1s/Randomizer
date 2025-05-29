#!/bin/bash

# Códigos de color ANSI para salidas coloridas | ANSI color codes for colored output
RED='\033[0;31m'
GREEN='\033[0;32m'
NC='\033[0m' # Sin color | No Color

# Archivos relacionados al servicio | Service-related files
SERVICE_FILE="/etc/systemd/system/randomizer.service"
SCRIPT_FILE="/usr/local/bin/randomizer.sh"

# Función para comprobar si se ejecuta como root | Function to check if running as root
check_root() {
    if [[ $EUID -ne 0 ]]; then
        echo -e "${NC}[${RED}!!${NC}] ${RED}Run the script as root.${NC}"
        exit 1
    fi
}

# Función para eliminar el servicio de systemd | Function to remove the systemd service
remove_systemd_service() {
    if [[ -f $SERVICE_FILE ]]; then
        systemctl unmask randomizer.service &>/dev/null
        systemctl stop randomizer.service &>/dev/null
        systemctl disable randomizer.service &>/dev/null
        rm -f "$SERVICE_FILE"
        systemctl daemon-reload
        echo -e "${NC}[${BLUE}+${NC}] ${GREEN}Systemd service eliminated.${NC}"
    else
        echo -e "${NC}[${RED}!!${NC}] ${RED}Systemd service file not found.${NC}"
    fi
}

# Función para eliminar el script de /usr/local/bin | Function to remove the script from /usr/local/bin
remove_script_file() {
    if [[ -f $SCRIPT_FILE ]]; then
        rm -f "$SCRIPT_FILE"
        echo -e "${NC}[${BLUE}+${NC}] ${GREEN}Script removed from /usr/local/bin.${NC}"
    else
        echo -e "${NC}[${RED}!!${NC}] ${RED}The script was not found in /usr/local/bin.${NC}"
    fi
}

# Función para eliminar la tarea cron | Function to remove the cron job
remove_cron_job() {
    crontab -l 2>/dev/null | grep -v "$SCRIPT_FILE" | crontab -
    echo -e "${NC}[${BLUE}+${NC}] ${GREEN}Cron task deleted.${NC}"
}

# Función principal para la desinstalación | Main function for uninstallation
main() {
    check_root
    remove_systemd_service
    remove_script_file
    remove_cron_job
    echo -e "${NC}[${GREEN}*${NC}] ${GREEN}Uninstallation complete.${NC}"
}

# Ejecutar la función principal | Run the main function
main

