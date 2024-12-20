#!/bin/bash

# Códigos de color ANSI | ANSI color codes
RED='\033[0;31m'
GREEN='\033[0;32m'
BLUE='\033[0;34m'
YELLOW='\033[0;33m'
NC='\033[0m' # Sin color | No Color

# Nombre del archivo de configuración para recordar la elección del usuario | Configuration file name to remember the user's choice
CONFIG_DIR="/etc/randomizer"
CONFIG_FILE="$CONFIG_DIR/randomizer.conf"

# Función para comprobar si se ejecuta como root | Function to check if running as root
check_root() {
    if [[ $EUID -ne 0 ]]; then
        echo -e "${RED}Run the script as root${NC}"
        exit 1
    fi
}

# Función para comprobar si las dependencias están instaladas | Function to check if dependencies are installed
check_dependencies() {
    # Verificar si existe el archivo de configuración y cargarlo si está presente | Check if config file exists and load it if it does
    if [[ -f "$CONFIG_FILE" ]]; then
        source "$CONFIG_FILE"
        echo -e "${GREEN}Configuration loaded from $CONFIG_FILE.${NC}"
        return
    fi

    # Lista de dependencias y faltantes | List of dependencies and missing ones
    local dependencies=("ip" "macchanger")
    local missing_dependencies=()

    # Verificar cada dependencia y agregar las faltantes | Check each dependency and add missing ones
    for dep in "${dependencies[@]}"; do
        if ! command -v "$dep" &> /dev/null; then
            missing_dependencies+=("$dep")
        fi
    done

    # Si falta iproute2 | If iproute2 is missing
    if [[ " ${missing_dependencies[*]} " == *" ip "* ]]; then
        read -p "iproute2 not found. Do you want to install it? (Y/N): " choice
        if [[ $choice == "Y" || $choice == "y" ]]; then
            install_iproute2
        elif [[ $choice == "N" || $choice == "n" ]]; then
            # Ofrecer instalación de macchanger si no quiere instalar iproute2
            read -p "Do you want to install macchanger instead? (Y/N): " choice
            if [[ $choice == "Y" || $choice == "y" ]]; then
                install_macchanger
            else
                echo -e "${RED}Both iproute2 and macchanger are required. Exiting...${NC}"
                exit 1
            fi
        else
            echo -e "${RED}Invalid option.${NC}"
            exit 1
        fi
    fi

    # Si falta macchanger y iproute2 está instalado | If macchanger is missing and iproute2 is installed
    if [[ " ${missing_dependencies[*]} " == *" macchanger "* ]]; then
        read -p "Macchanger not found. Do you want to install it or use only iproute2 (Recomended to use iproute2)? (install/ip): " choice
        if [[ $choice == "install" ]]; then
            install_macchanger
        elif [[ $choice == "ip" ]]; then
            echo 'USE_ONLY_IP="true"' > "$CONFIG_FILE"
        else
            echo -e "${RED}Invalid option.${NC}"
            exit 1
        fi
    fi
}


# Función para instalar macchanger | Function to install macchanger
install_macchanger() {
    apt update && apt install -y macchanger
    if [[ $? -ne 0 ]]; then
        echo -e "${RED}Failed to install macchanger. Please install it manually.${NC}"
        exit 1
    fi
    echo "USE_ONLY_IP=false" > "$CONFIG_FILE"
    echo -e "${GREEN}macchanger installed successfully.${NC}"
}

# Función para instalar iproute2 | Function to install iproute2
install_iproute2(){
    apt update && apt install -y iproute2
    if [[ $? -ne 0 ]]; then
        echo -e "${RED}Failed to install iproute2. Please install it manually.${NC}"
        exit 1
    fi
    echo "USE_ONLY_IP=false" > "$CONFIG_FILE"
    echo -e "${GREEN}iproute2 installed successfully.${NC}"
        
}

# Función para randomizar las MACs usando ip o macchanger | Function to randomize MACs using ip or macchanger
randomize_macs() {
    local interfaces=$(ip -o link show | awk -F': ' '{print $2}')

    for iface in $interfaces; do
        if [[ $iface != "lo" ]]; then
            ip link set dev "$iface" down
            echo -e "${BLUE}$iface${NC} ${RED}is down.${NC}"

            if [[ "$USE_ONLY_IP" == true ]]; then               
                # Usar solo ip para cambiar la MAC | Use only ip to change the MAC
                local valid_mac=false
                while [[ $valid_mac == false ]]; do
                
                    new_mac=$(generate_random_mac)
                    echo -e "${YELLOW}Trying to set MAC ${BLUE}$iface${NC} to ${YELLOW}$new_mac${NC}"
                    
                    ip link set dev "$iface" address "$new_mac"
                    if [[ $? -eq 0 ]]; then
                        valid_mac=true
                        echo -e "${YELLOW}MAC of ${BLUE}$iface${NC} changed to ${YELLOW}$new_mac${NC}"
                    else
                        echo -e "${RED}Failed to assign MAC ${new_mac} to ${iface}. Generating a new one...${NC}"
                    fi
                done
            else
                # Usar macchanger | Use macchanger
                maccommand=$(macchanger -r "$iface")
                
                echo "$maccommand"
                new_mac=$(ip link show "$iface" | awk '/ether/ {print $2}')
                echo -e "${YELLOW}MAC of ${BLUE}$iface${NC} changed to ${YELLOW}$new_mac${NC}"
            fi

            ip link set dev "$iface" up
            echo -e "${BLUE}$iface${NC} ${GREEN}is up.${NC}"
        fi
    done
}

# Función para generar una MAC aleatoria | Function to generate a random MAC
generate_random_mac() {
    local mac_suffix=$(printf '%02X:%02X:%02X:%02X:%02X:%02X' $((RANDOM % 256)) $((RANDOM % 256)) $((RANDOM % 256)) $((RANDOM % 256)) $((RANDOM % 256)) $((RANDOM % 256)))
    echo "$mac_suffix"
}

# Función para crear un servicio de systemd | Function to create a systemd service
create_systemd_service() {
    wget "https://raw.githubusercontent.com/4p0f1s/Randomizer/refs/heads/main/randomizer.service" -O /etc/systemd/system/randomizer.service
    # Crear el script que ejecutará el servicio | Create the script that will execute the service
    cp "$0" /usr/local/bin/randomizer.sh
    chmod +x /usr/local/bin/randomizer.sh

    # Habilitar y iniciar el servicio | Enable and start the service
    systemctl enable randomizer.service
    systemctl start randomizer.service

    echo -e "${GREEN}MAC randomization service created and enabled.${NC}"
}

# Función para crear un cron job | Function to create a cron job
create_cron_job() {
    local cron_expression
    while true; do
        echo -e "If you need help you can go to https://crontab.guru/"
        read -p "Enter the cron expression for the execution frequency (e.g. every hour: 0 * * * *): " cron_expression
        if [[ $(echo "$cron_expression" | grep -E "^[0-9,\*/-]+\s+[0-9,\*/-]+\s+[0-9,\*/-]+\s+[0-9,\*/-]+\s+[0-9,\*/-]+$") ]]; then
            break
        else
            echo -e "${RED}Invalid cron format. Please try again.${NC}"
        fi
    done

    (crontab -l 2>/dev/null; echo "$cron_expression /usr/local/bin/randomizer.sh") | crontab -
    echo -e "${GREEN}Cron scheduled task created successfully.${NC}"
}

# Función principal | Main function
main() {
    check_root
    if [[ ! -f $CONFIG_FILE ]]; then
        mkdir $CONFIG_DIR
        check_dependencies
        randomize_macs
        sleep 4
        create_systemd_service
        create_cron_job
        echo -e "${GREEN}Installation and configuration completed.${NC}"
    else
        check_dependencies
        randomize_macs
    fi
}

# Ejecutar la función principal | Run the main function
main
