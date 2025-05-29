#!/bin/bash

# Códigos de color ANSI | ANSI color codes
RED='\033[0;31m'
GREEN='\033[0;32m'
BLUE='\033[0;34m'
YELLOW='\033[0;33m'
NC='\033[0m' # Sin color | No Color

QUIET=false  # Modo silencioso | Quiet mode

# Función para comprobar requisitos para que funcione el script | Function to verify the requirements needed for the script to work
check_reqs() {
    check_root
    check_dependencies
}

# Función para verificar que se ejecuta como root | Function to verify that is executed by root
check_root() {
    if [[ $EUID -ne 0 ]]; then
        [[ $QUIET == false ]] && echo -e "${RED}Run the script as root${NC}"
        exit 1
    fi
}

# Función para verificar dependencias | Function to check dependencies
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
        [[ $QUIET == false ]] && echo -e "${NC}[${GREEN}*${NC}] ${GREEN}All dependencies are installed.${NC}"
    else
        [[ $QUIET == false ]] && echo -e "${NC}[${YELLOW}!${NC}] ${YELLOW}Missing packages: ${missing_packages[*]}${NC}"
        if [[ $QUIET == true ]]; then
            exit 1
        fi
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

# Función para randomizar las MACs | Function to randomize MACs
randomize_macs() {
    local interfaces=$(ip -o link show | awk -F': ' '{print $2}')

    for iface in $interfaces; do
        # Saltar interfaces virtuales y loopback | Skip virtual and loopback interfaces
        if [[ "$iface" == "lo" ]] || is_virtual_iface "$iface"; then
            [[ $QUIET == false ]] && echo -e "${NC}[${YELLOW}!${NC}] ${YELLOW}Skipping virtual interface ${BLUE}$iface${NC}"
            continue
        fi

        # Poner la interfaz abajo | Set interface down
        ip link set dev "$iface" down
        [[ $QUIET == false ]] && echo -e "${NC}[${BLUE}+${NC}] ${BLUE}$iface${NC} ${RED}is down.${NC}"

        # Generar e intentar aplicar una MAC aleatoria | Generate and try applying random MAC
        local valid_mac=false
        while [[ $valid_mac == false ]]; do
            new_mac=$(generate_random_mac)
            [[ $QUIET == false ]] && echo -e "${NC}[${BLUE}+${NC}] ${YELLOW}Trying to set MAC ${BLUE}$iface${NC} to ${YELLOW}$new_mac${NC}"

            ip link set dev "$iface" address "$new_mac" 2>/dev/null
            if [[ $? -eq 0 ]]; then
                valid_mac=true
                [[ $QUIET == false ]] && echo -e "${NC}[${GREEN}*${NC}] ${YELLOW}MAC of ${BLUE}$iface${NC} changed to ${YELLOW}$new_mac${NC}"
            else
                [[ $QUIET == false ]] && echo -e "${NC}[${RED}!!${NC}] Failed to assign MAC ${new_mac} to ${iface}. Generating a new one...${NC}"
            fi
        done

        # Volver a activar la interfaz | Bring interface back up
        ip link set dev "$iface" up
        [[ $QUIET == false ]] && echo -e "${NC}[${GREEN}*${NC}] ${BLUE}$iface${NC} ${GREEN}is up.${NC}"
    done
}

# Función principal | Main Function
main() {
    # Comprobar si se pasó --quiet o -q como parámetro | Check if --quiet mode is enabled
    if [[ "$1" == "-q" || "$1" == "--quiet" ]]; then
        QUIET=true
    fi

    check_reqs
    randomize_macs
}

# Ejecutar la función principal | Run the main function
main "$@"
