#!/bin/bash
# Color definitions
CYAN='\033[0;36m'
MAGENTA='\033[0;35m'
YELLOW='\033[1;33m'
GREEN='\033[0;32m'
WHITE='\033[1;37m'
RED='\033[0;31m'
NC='\033[0m  # Reset color

# Paths
LOG_FILE="/var/log/psiphon_instance.log"  # Log file path
PSIPHON_DIR="/opt/psiphon3"  # Psiphon installation directory
PSIPHON_BINARY="$PSIPHON_DIR/psiphon3"  # Psiphon executable file

# Ensure the log directory exists
mkdir -p $(dirname $LOG_FILE)

# Check if Psiphon is installed
function check_psiphon_status() {
    if command -v $PSIPHON_BINARY > /dev/null; then
        echo -e "${GREEN}======= Psiphon is installed. =======${NC}"
        return 0
    else
        echo -e "${RED}======= Psiphon is not installed. =======${NC}"
        return 1
    fi
}

# Install Psiphon
function install_psiphon() {
    echo -e "${YELLOW}Installing Psiphon...${NC}"
    # Example installation (change according to your source)
    sudo apt update && sudo apt install -y psiphon3
    if [[ $? -eq 0 && -f $PSIPHON_BINARY ]]; then
        echo -e "${GREEN}Psiphon successfully installed.${NC}"
    else
        echo -e "${RED}Error installing Psiphon. Please check your internet connection or repository configuration.${NC}"
    fi
}

# Uninstall Psiphon
function uninstall_psiphon() {
    echo -e "${YELLOW}Uninstalling Psiphon...${NC}"
    sudo apt remove -y psiphon3 && sudo apt purge -y psiphon3
    if [[ $? -eq 0 && ! -f $PSIPHON_BINARY ]]; then
        echo -e "${GREEN}Psiphon successfully uninstalled.${NC}"
    else
        echo -e "${RED}Error uninstalling Psiphon. Psiphon might still be partially installed.${NC}"
    fi
}

# Show main menu
function show_menu() {
    echo -e "${CYAN}======================================${NC}"
    echo -e "${GREEN}        Psiphon Management Script      ${NC}"
    echo -e "${CYAN}======================================${NC}"
    
    # Psiphon status check
    check_psiphon_status
    
    echo -e "${CYAN}======= Psiphon Management Menu =======${NC}"
    echo -e "${WHITE}1)${NC} Install Psiphon"
    echo -e "${WHITE}2)${NC} Uninstall Psiphon"
    echo -e "${WHITE}3)${NC} Add New Configuration"
    echo -e "${WHITE}4)${NC} View Existing Configurations"
    echo -e "${WHITE}5)${NC} Delete Configuration"
    echo -e "${WHITE}6)${NC} Schedule IP Change"
    echo -e "${WHITE}7)${NC} Show Current IP"
    echo -e "${WHITE}8)${NC} Test Connection"
    echo -e "${WHITE}9)${NC} Psiphon Service Status"
    echo -e "${WHITE}10)${NC} Backup Configurations"
    echo -e "${WHITE}11)${NC} Edit Local IP"
    echo -e "${WHITE}0)${NC} Exit"
    echo -e "${CYAN}======================================${NC}"
    echo -e "${YELLOW}Please choose an option (0-11):${NC}"
    read choice
}

# Function to validate country code
function validate_country_code() {
    local country_code=$1
    if [[ ! $country_code =~ ^[A-Z]{2}$ ]]; then
        echo -e "${RED}Invalid country code. Please use a valid ISO code (e.g., FR, IT, TR).${NC}"
        echo "$(date) - Error: Invalid country code entered: $country_code" >> $LOG_FILE
        return 1
    fi
    return 0
}

# Function to validate IP address
function validate_ip() {
    local ip=$1
    if [[ ! $ip =~ ^[0-9]+\.[0-9]+\.[0-9]+\.[0-9]+$ ]]; then
        echo -e "${RED}Invalid IP address. Please enter a valid IP (e.g., 192.168.1.1).${NC}"
        echo "$(date) - Error: Invalid IP entered: $ip" >> $LOG_FILE
        return 1
    fi
    return 0
}

# Function to add new Psiphon instance with proper port settings
function add_instance() {
    while true; do
        echo -e "${YELLOW}Enter country code (e.g., fr, it, tr):${NC}"
        read country_code

        # Convert country code to uppercase and validate
        country_code=$(echo "$country_code" | tr '[:lower:]' '[:upper:]')
        validate_country_code $country_code || return

        # Starting port number (for example 1080)
        starting_port=1080
        local_port=$starting_port

        # Find a free port
        while true; do
            # Check if the port is already used in the configuration
            if ! grep -q "SocksPort $local_ip:$local_port" "$PSIPHON_DIR/psiphon3.conf"; then
                break  # Port is available
            fi
            ((local_port++))  # Increment the port number if it's already in use
        done

        # Request IP from user
        echo -e "${YELLOW}Enter local IP (default is 127.0.0.1):${NC}"
        read local_ip
        local_ip=${local_ip:-127.0.0.1}  # Default to 127.0.0.1 if not provided

        # Validate IP
        validate_ip $local_ip || return

        # Check if Psiphon is running
        if ! ps aux | grep -q '[p]siphon3'; then
            echo -e "${RED}Psiphon is not running. Please start Psiphon first.${NC}"
            return
        fi

        # Check if Psiphon configuration file exists
        if [[ ! -f "$PSIPHON_DIR/psiphon3.conf" ]]; then
            echo -e "${RED}Psiphon configuration file not found: $PSIPHON_DIR/psiphon3.conf${NC}"
            echo "$(date) - Error: Psiphon configuration file not found." >> $LOG_FILE
            return
        fi

        # Add configuration directly to Psiphon config file
        {
            echo "SocksPort $local_ip:$local_port"
            echo "ExitNodes {$country_code}"
            echo "StrictNodes 1"
        } | sudo tee -a "$PSIPHON_DIR/psiphon3.conf" > /dev/null

        if [ $? -eq 0 ]; then
            echo -e "${GREEN}Instance created successfully with the following details:${NC}"
            echo -e "Country code: $country_code"
            echo -e "Local IP: $local_ip"
            echo -e "Port: $local_port"
        else
            echo -e "${RED}Failed to write to $PSIPHON_DIR/psiphon3.conf.${NC}"
            return
        fi

        # Reload Psiphon service
        sudo systemctl restart psiphon3
        if [ $? -eq 0 ]; then
            echo -e "${GREEN}Psiphon service restarted successfully.${NC}"
        else
            echo -e "${RED}Failed to restart Psiphon service. Please check the configuration.${NC}"
        fi

        # Ask to continue or exit
        echo -e "${YELLOW}Press Enter to add another instance or type 'exit' to go back to the main menu:${NC}"
        read user_input
        if [[ -z $user_input ]]; then
            echo -e "${CYAN}Adding new instance...${NC}"
            continue
        elif [[ "$user_input" == "exit" ]]; then
            echo -e "${CYAN}Exiting...${NC}"
            break
        fi
    done
}
