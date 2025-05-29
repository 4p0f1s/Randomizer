#!/bin/bash

# Códigos de color ANSI | ANSI color codes
RED='\033[0;31m'
GREEN='\033[0;32m'
BLUE='\033[0;34m'
YELLOW='\033[0;33m'
NC='\033[0m' # Sin color | No Color

# Función para comprobar si se ejecuta como root | Function to check if running as root
check_root() {
    if [[ $EUID -ne 0 ]]; then
        echo -e "${NC}[${RED}!!${NC}] ${RED}Run the script as root${NC}"
        exit 1
    fi
}

# Función para comprobar si las dependencias están instaladas | Function to check if dependencies are installed
check_dependencies() {
    # Lista de dependencias necesarias | List of necessary dependencies
    declare -A DEPENDENCY_MAP=( ["ip"]="iproute2" )

    local missing_packages=()

    for cmd in "${!DEPENDENCY_MAP[@]}"; do
        if ! command -v "$cmd" &> /dev/null; then
            missing_packages+=("${DEPENDENCY_MAP[$cmd]}")
        fi
    done

    if [[ ${#missing_packages[@]} -eq 0 ]]; then
        echo -e "${NC}[${GREEN}*${NC}] ${GREEN}All dependencies are installed.${NC}"
    else
        echo -e "${NC}[${YELLOW}!${NC}] ${YELLOW}Missing packages: ${missing_packages[*]}${NC}"
        read -p "${NC}[${BLUE}-${NC}] ${GREEN}Do you want to install them? (y/n): " answer

        if [[ $answer == "y" ]]; then
            install_dependencies "${missing_packages[@]}"
        else
            echo -e "${NC}[${RED}!!${NC}] ${RED}Cannot continue without installing dependencies.${NC}"
            exit 1
        fi
    fi
}

# Función para instalar dependencias | Function to install dependencies
install_dependencies() {
    apt update
    for package in "$@"; do
        apt install -y "$package"
    done
}

# Función para comprobar si la interfaz de red es virtual | Function to check if the network interface is virtual
is_virtual_iface() {
    [[ -d "/sys/devices/virtual/net/$1" ]]
}

# Función para generar una MAC aleatoria | Function to generate a random MAC
generate_random_mac() {
    local mac_suffix=$(printf '%02X:%02X:%02X:%02X:%02X:%02X' $((RANDOM % 256)) $((RANDOM % 256)) $((RANDOM % 256)) $((RANDOM % 256)) $((RANDOM % 256)) $((RANDOM % 256)))
    echo "$mac_suffix"
}

# Función para randomizar las MACs usando ip o macchanger | Function to randomize MACs using ip or macchanger
randomize_macs() {
    local interfaces=$(ip -o link show | awk -F': ' '{print $2}')

    for iface in $interfaces; do
        if [[ "$iface" == "lo" ]] || is_virtual_iface "$iface"; then
            echo -e "${NC}[${YELLOW}!${NC}] ${YELLOW}Skipping virtual interface ${BLUE}$iface${NC}"
            continue
        fi

        ip link set dev "$iface" down
        echo -e "${NC}[${BLUE}+${NC}] ${BLUE}$iface${NC} ${RED}is down.${NC}"

        local valid_mac=false
        while [[ $valid_mac == false ]]; do
            new_mac=$(generate_random_mac)
            echo -e "${NC}[${BLUE}+${NC}] ${YELLOW}Trying to set MAC ${BLUE}$iface${NC} to ${YELLOW}$new_mac${NC}"

            ip link set dev "$iface" address "$new_mac" 2>/dev/null
            if [[ $? -eq 0 ]]; then
                valid_mac=true
                echo -e "${NC}[${GREEN}*${NC}] ${YELLOW}MAC of ${BLUE}$iface${NC} changed to ${YELLOW}$new_mac${NC}"
            else
                echo -e "${NC}[${RED}!!${NC}] ${RED}Failed to assign MAC ${new_mac} to ${iface}. Generating a new one...${NC}"
            fi
        done

        ip link set dev "$iface" up
        echo -e "${NC}[${GREEN}*${NC}] ${BLUE}$iface${NC} ${GREEN}is up.${NC}"
    done
}

# Función para crear un servicio de systemd | Function to create a systemd service
create_systemd_service() {
    wget "https://raw.githubusercontent.com/4p0f1s/Randomizer/refs/heads/main/randomizer.service" -O /etc/systemd/system/randomizer.service
    # Crear el script que ejecutará el servicio | Create the script that will execute the service
    cp "$0" /usr/local/bin/randomizer.sh
    chmod +x /usr/local/bin/randomizer.sh

    # Habilitar el servicio | Enable the service
    systemctl enable randomizer.service


    echo -e "${NC}[${GREEN}*${NC}] ${GREEN}MAC randomization service created and enabled.${NC}"
}

# Función para crear un cron job | Function to create a cron job
create_cron_job() {
    local cron_expression

    while true; do
        echo -e "${NC}[${BLUE}+${NC}] ${BLUE}If you need help you can go to https://crontab.guru/"
        echo -e "${NC}[${BLUE}-${NC}] ${BLUE}Enter the cron expression for the execution frequency (e.g. every hour: 0 * * * *):${NC}"
        read -p "> " cron_expression
        if [[ $(echo "$cron_expression" | grep -E "^[0-9,\*/-]+\s+[0-9,\*/-]+\s+[0-9,\*/-]+\s+[0-9,\*/-]+\s+[0-9,\*/-]+$") ]]; then
            break
        else
            echo -e "${NC}[${RED}!!${NC}] ${RED}Invalid cron format. Please try again.${NC}"
        fi
    done

    (crontab -l 2>/dev/null; echo "$cron_expression /usr/local/bin/randomizer.sh --randomize") | crontab -
    echo -e "${NC}[${GREEN}*${NC}] ${GREEN}Cron scheduled task created successfully.${NC}"
}

# Función principal | Main function
main() {
    check_root
    check_dependencies
    if [[ "$1" == "-r" || "$1" == "--randomize" ]]; then
      randomize_macs
      exit 0
    else
    randomize_macs
    sleep 4
    create_systemd_service
    create_cron_job
    echo -e "${NC}[${GREEN}*${NC}] ${GREEN}Installation and configuration completed.${NC}"
    fi
}

# Ejecutar la función principal | Run the main function
main
