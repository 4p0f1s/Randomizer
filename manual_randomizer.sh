#!/bin/bash

# Códigos de color ANSI | ANSI color codes
RED='\033[0;31m'
GREEN='\033[0;32m'
BLUE='\033[0;34m'
YELLOW='\033[0;33m'
NC='\033[0m' # Sin color | No Color

# Lista de dependencias necesarias | List of necessary dependencies
DEPENDENCIES=("macchanger" "ip")

# Función para comprobar requisitos para que funcione el script | Function to verify the requirements needed for the script to work
check_reqs() {
    check_root
    check_dependencies
}

# Función para verificar que se ejecuta como root | Function to verify that is executed by root
check_root() {
    if [[ $USER != "root" ]]; then
        echo -e "${RED}Run the script as root${NC}"
        exit 1
    fi
}

# Función para verificar dependencias | Function to check dependencies
check_dependencies() {
    local missing_dependencies=()

    for dependency in "${DEPENDENCIES[@]}"; do
        if ! command -v "$dependency" &> /dev/null; then
            missing_dependencies+=("$dependency")
        fi
    done

    if [[ ${#missing_dependencies[@]} -eq 0 ]]; then
        echo "All dependencies are installed."
    else
        echo -e "${YELLOW}The following dependencies are missing: ${missing_dependencies[*]}${NC}"
        read -p "Do you want to install them? (y/n): " answer

        if [[ $answer == "y" ]]; then
            install_dependencies "${missing_dependencies[@]}"
        else
            echo -e "${RED}Cannot continue without installing dependencies.${NC}"
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

# Función para tirar abajo las interfaces | Function to change the interfaces status to down
down_interfaces() {
    for iface in $(ip -o link show | awk -F': ' '{print $2}'); do
        if [[ $iface != "lo" ]]; then
            ip link set "$iface" down
            echo -e "${BLUE}$iface${NC} ${RED}is down.${NC}"
        fi
    done
}

# Función para randomizar las MACs | Function to randomize MACs
randomize_macs() {
    for iface in $(ip -o link show | awk -F': ' '{print $2}'); do
        if [[ $iface != "lo" ]]; then
            macchanger -r "$iface"
            echo -e "${GREEN}MAC of ${BLUE}$iface${GREEN} has been randomized.${NC}"
        fi
    done
}

# Función para comprobar las MACs | Function to verify MACs
check_macs() {
    for iface in $(ip -o link show | awk -F': ' '{print $2}'); do
        if [[ $iface != "lo" ]]; then
            new_mac=$(ip link show "$iface" | awk '/ether/ {print $2}')
            if [[ ${original_macs[$iface]} != "$new_mac" ]]; then
                echo -e "${YELLOW}The MAC of ${BLUE}$iface${YELLOW} has changed from ${BLUE}${original_macs[$iface]}${YELLOW} to ${BLUE}$new_mac${NC}"
            else
                echo -e "${YELLOW}The MAC of ${BLUE}$iface${YELLOW} hasn't changed: ${BLUE}$new_mac${NC}"
            fi
        fi
    done
}

# Función para levantar las interfaces | Function to change the interfaces status to up
up_interfaces() {
    for iface in $(ip -o link show | awk -F': ' '{print $2}'); do
        if [[ $iface != "lo" ]]; then
            ip link set "$iface" up
            echo -e "${BLUE}$iface${NC} ${GREEN}is up.${NC}"
        fi
    done
}

# Guardar las MACs originales | Store the original MACs
declare -A original_macs
for iface in $(ip -o link show | awk -F': ' '{print $2}'); do
    if [[ $iface != "lo" ]]; then
        original_macs["$iface"]=$(ip link show "$iface" | awk '/ether/ {print $2}')
    fi
done

# Función main | Main Function
main() {
    check_reqs
    down_interfaces
    randomize_macs
    check_macs
    up_interfaces
}

main

