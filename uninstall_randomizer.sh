#!/bin/bash

# Códigos de color ANSI para salidas coloridas | ANSI color codes for colored output
RED='\033[0;31m'
GREEN='\033[0;32m'
NC='\033[0m' # Sin color | No Color

# Nombre del archivo de configuración y otros archivos relacionados | Name of the configuration file and other related files
CONFIG_DIR="/etc/randomizer"
CONFIG_FILE="$CONFIG_DIR/mac_randomizer.conf"
SERVICE_FILE="/etc/systemd/system/mac_randomizer.service"
SCRIPT_FILE="/usr/local/bin/mac_randomizer.sh"

# Función para comprobar si se ejecuta como root | Function to check if running as root
check_root() {
    if [[ $EUID -ne 0 ]]; then
        echo -e "${RED}Run the script as root.${NC}"
        exit 1
    fi
}

# Función para eliminar el servicio de systemd | Function to remove the systemd service
remove_systemd_service() {
    if [[ -f $SERVICE_FILE ]]; then
        systemctl stop mac_randomizer.service
        systemctl disable mac_randomizer.service
        rm -f "$SERVICE_FILE"
        systemctl daemon-reload
        echo -e "${GREEN}Systemd service eliminated.${NC}"
    else
        echo -e "${RED}Systemd service file not found.${NC}"
    fi
}

# Función para eliminar el archivo de configuración | Function to remove the configuration file
remove_config_files() {
    if [[ -d $CONFIG_DIR ]]; then
        rm -rf "$CONFIG_DIR"
        echo -e "${GREEN}Deleted configuration file(s).${NC}"
    else
        echo -e "${RED}The configuration directory was not found.${NC}"
    fi
}

# Función para eliminar el script de /usr/local/bin | Function to remove the script from /usr/local/bin
remove_script_file() {
    if [[ -f $SCRIPT_FILE ]]; then
        rm -f "$SCRIPT_FILE"
        echo -e "${GREEN}Script removed from /usr/local/bin.${NC}"
    else
        echo -e "${RED}The script was not found in /usr/local/bin.${NC}"
    fi
}

# Función para eliminar la tarea cron | Function to remove the cron job
remove_cron_job() {
    crontab -l | grep -v "$SCRIPT_FILE" | crontab -
    echo -e "${GREEN}Cron task deleted.${NC}"
}

# Función para desinstalar macchanger si fue instalado | Function to uninstall macchanger if it was installed
uninstall_macchanger() {
    if dpkg -l | grep -q "macchanger"; then
        apt remove --purge -y macchanger
        echo -e "${GREEN}MacChanger uninstalled.${NC}"
    else
        echo -e "${RED}MacChanger is not installed.${NC}"
    fi
}

# Función principal para la desinstalación | Main function for uninstallation
main() {
    check_root
    remove_systemd_service
    remove_config_files
    remove_script_file
    remove_cron_job
    uninstall_macchanger
    echo -e "${GREEN}Uninstallation complete.${NC}"
}

# Ejecutar la función principal | Run the main function
main
