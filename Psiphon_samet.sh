#!/bin/bash
# Color definitions
CYAN='\033[0;36m'
MAGENTA='\033[0;35m'
YELLOW='\033[1;33m'
GREEN='\033[0;32m'
WHITE='\033[1;37m'
RED='\033[0;31m'
NC='\033[0m' # Reset color

# Paths
LOG_FILE="/var/log/psiphon_instance.log"  # Log file path
PSIPHON_DIR="/opt/psiphon3"  # Psiphon installation directory
PSIPHON_BINARY="$PSIPHON_DIR/psiphon3"  # Psiphon executable file

# Ensure the log directory exists
mkdir -p $(dirname $LOG_FILE)

# Check if Psiphon is installed
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
# Install Psiphon
function install_psiphon() {
    # First, check if Psiphon is already installed
    if check_psiphon_status; then
        echo -e "${GREEN}Psiphon is already installed. No need to install again.${NC}"
        return
    fi
    
    echo -e "${YELLOW}Installing Psiphon...${NC}"

    # Check if the system supports installing Psiphon from a repository
    sudo apt update && sudo apt install -y psiphon3
    
    # If installation is successful, verify that the Psiphon binary exists
    if [[ $? -eq 0 && -f "$PSIPHON_BINARY" ]]; then
        echo -e "${GREEN}Psiphon successfully installed.${NC}"
    else
        echo -e "${RED}Error installing Psiphon. Please check your internet connection or repository configuration.${NC}"
    fi
}

# Uninstall Psiphon
function uninstall_psiphon() {
    echo -e "${YELLOW}Uninstalling Psiphon...${NC}"
    
    sudo apt remove -y psiphon3 && sudo apt purge -y psiphon3
    
    # If uninstallation is successful, verify that the Psiphon binary no longer exists
    if [[ $? -eq 0 && ! -f "$PSIPHON_BINARY" ]]; then
        echo -e "${GREEN}Psiphon successfully uninstalled.${NC}"
    else
        echo -e "${RED}Error uninstalling Psiphon. Psiphon might still be partially installed.${NC}"
    fi
}

# Display the menu
function show_menu() {
    echo -e "${CYAN}======================================${NC}"
    echo -e "${GREEN}        Psiphon Management Script      ${NC}"
    echo -e "${CYAN}======================================${NC}"

    # Display the Psiphon installation status with color
    if check_psiphon_status; then
        echo -e "${GREEN}Psiphon is installed.${NC}"
    else
        echo -e "${RED}Psiphon is not installed.${NC}"
    fi
    
    echo -e "${CYAN}======= Psiphon Management Menu =======${NC}"
    echo -e "${WHITE}1)${NC} Install Psiphon"
    echo -e "${WHITE}2)${NC} Uninstall Psiphon"
    echo -e "${WHITE}3)${NC} Add New Configuration"
    echo -e "${WHITE}4)${NC} Show Created List of IPs"
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
    
    case $choice in
        1) install_psiphon ;;
        2) uninstall_psiphon ;;
        3) add_configuration ;;
        4) show_created_ips ;;
        5) delete_configuration ;;
        6) schedule_ip_change ;;
        7) show_current_ip ;;
        8) test_connection ;;
        9) psiphon_service_status ;;
        10) backup_configurations ;;
        11) edit_local_ip ;;
        0) exit_script ;;
        *) echo -e "${RED}Invalid choice! Please select a valid option.${NC}" ;;
    esac
}

# Function to validate country code
function validate_country_code() {
    local country_code=$(echo "$1" | tr '[:lower:]' '[:upper:]')  # Convert to uppercase
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
    if [[ ! $ip =~ ^([0-9]{1,3}\.){3}[0-9]{1,3}$ ]] || [[ "$ip" =~ \.\. ]]; then
        echo -e "${RED}Invalid IP address. Please enter a valid IP (e.g., 192.168.1.1).${NC}"
        echo "$(date) - Error: Invalid IP entered: $ip" >> $LOG_FILE
        return 1
    fi
    # Check if IP is within valid range (0-255)
    IFS='.' read -r -a octets <<< "$ip"
    for octet in "${octets[@]}"; do
        if [[ "$octet" -lt 0 || "$octet" -gt 255 ]]; then
            echo -e "${RED}Invalid IP address. Each octet must be between 0 and 255.${NC}"
            echo "$(date) - Error: Invalid IP entered (octet out of range): $ip" >> $LOG_FILE
            return 1
        fi
    done
    return 0
}

function add_instance() {
    while true; do
        echo -e "${YELLOW}Enter country code (e.g., FR, IT, TR):${NC}"
        read country_code

        # Convert country code to uppercase and validate
        country_code=$(echo "$country_code" | tr '[:lower:]' '[:upper:]')
        validate_country_code $country_code || return

        # Starting port number (for example 1080)
        starting_port=1080
        
        # Request port from user (default is 1080 if left empty)
        echo -e "${YELLOW}Enter port number (default is $starting_port):${NC}"
        read local_port
        local_port=${local_port:-$starting_port}  # Default to 1080 if no input is given

        # Validate port number
        if [[ ! $local_port =~ ^[0-9]+$ || $local_port -lt 1024 || $local_port -gt 65535 ]]; then
            echo -e "${RED}Invalid port number. Please enter a number between 1024 and 65535.${NC}"
            continue
        fi

        # Find a free port if the entered one is already in use
        while true; do
            if ! grep -q "SocksPort $local_ip:$local_port" "$PSIPHON_DIR/psiphon3.conf"; then
                break  # Port is available
            fi
            ((local_port++))  # Increment the port number if it's already in use
            echo -e "${YELLOW}Port $local_port is already in use. Trying next port...${NC}"
        done

        # Request IP from user
        echo -e "${YELLOW}Enter local IP (default is 127.0.0.1):${NC}"
        read local_ip
        local_ip=${local_ip:-127.0.0.1}  # Default to 127.0.0.1 if not provided

        # Validate IP address
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
            echo -e "${RED}Failed to write to $PSIPHON_DIR/psiphon3.conf. Please check the permissions or file path.${NC}"
            echo "$(date) - Error: Failed to write to Psiphon config file." >> $LOG_FILE
            return
        fi

        # Reload Psiphon service
        sudo systemctl restart psiphon3
        if [ $? -eq 0 ]; then
            echo -e "${GREEN}Psiphon service restarted successfully.${NC}"
        else
            echo -e "${RED}Failed to restart Psiphon service. Please check the configuration.${NC}"
            return
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


function schedule_ip_change() {
    while true; do
        clear  # Clear the screen
        echo "**How often should the IP change for Psiphon? (minutes, e.g., 10):"
        read interval

        if [ -z "$interval" ]; then
            # If no input is given, exit the loop and return to the menu
            break
        fi

        # Check if interval is a positive integer
        if ! [[ "$interval" =~ ^[0-9]+$ ]] || [ "$interval" -le 0 ]; then
            echo -e "${RED}Invalid input. Please enter a positive integer for the interval.${NC}"
            continue  # Ask again if the input is invalid
        fi

        # Add cron job to change IP by restarting Psiphon at the specified interval
        echo "*/$interval * * * * root sudo systemctl restart psiphon3" | sudo tee -a /etc/crontab > /dev/null

        # Check if the crontab entry was added successfully
        if [ $? -eq 0 ]; then
            echo -e "${GREEN}Psiphon IP change has been set to every $interval minutes.${NC}"
        else
            echo -e "${RED}Failed to add cron job. Please check permissions or try again.${NC}"
        fi

        # Clear the screen to show updated status
        echo -e "${CYAN}Press Enter to return to the menu...${NC}"
        read -p "Press Enter to continue: "  # Wait for user input
        if [ -z "$REPLY" ]; then
            break  # If Enter is pressed, exit the loop and return to the menu
        fi
    done
}


function show_current_ip() {
    while true; do
        clear  # Clear the screen
        echo -e "${CYAN}Enter the port to check the IP (or press Enter to exit):${NC}"
        read check_port

        # Exit if no port is entered
        if [ -z "$check_port" ]; then
            break
        fi

        # Check if Psiphon is running
        if ! ps aux | grep -q '[p]siphon3'; then
            echo -e "${RED}Psiphon is not running. Please start Psiphon first.${NC}"
            break
        fi

        # Check if Psiphon is using the provided port
        if nc -zv 127.0.0.1 "$check_port" &>/dev/null; then
            echo -e "${GREEN}Connection is successful on port $check_port.${NC}"
        else
            echo -e "${RED}Error: Connection failed on port $check_port.${NC}"
        fi

        # Wait for user to press Enter to continue or exit
        echo -e "\nPress Enter to return to the menu..."
        read -p "Press Enter to continue: " user_input

        if [ -z "$user_input" ]; then
            break
        fi
    done
}



# Function to test connection using a specific port
function test_connection() {
    while true; do
        clear  # Clear the screen
        echo -e "${CYAN}Enter the port to test the connection (or press Enter to exit):${NC}"
        read test_port

        if [ -z "$test_port" ]; then
            break  # Exit the loop if no input is given
        fi

        # Test the connection using curl with error handling
        echo -e "Testing connection on port $test_port..."
        
        curl --socks5-hostname 127.0.0.1:$test_port https://www.google.com -I --silent --max-time 10
        if [ $? -eq 0 ]; then
            echo -e "${GREEN}Connection successful on port $test_port.${NC}"
        else
            echo -e "${RED}Connection failed on port $test_port.${NC}"
        fi

        # Wait for user to press Enter to continue or exit
        echo -e "\nPress Enter to return to the menu..."
        read -p "Press Enter to continue: "  # Wait for user input

        if [ -z "$REPLY" ]; then
            break  # Exit if Enter is pressed
        fi
    done
}

# Function to check the status of the Psiphon service
function check_service_status() {
    echo -e "${YELLOW}Psiphon service status:${NC}"
    sudo systemctl status psiphon | grep "Active" || echo -e "${RED}Psiphon service is not running.${NC}"
}

# Function to backup Psiphon configuration file
function backup_psiphon_config() {
    if [ -f "$psiphon_config_file" ]; then
        sudo cp "$psiphon_config_file" "$psiphon_config_file.bak"
        echo -e "${GREEN}The settings backup has been saved in the file $psiphon_config_file.bak.${NC}"
    else
        echo -e "${RED}Error: Psiphon configuration file not found. Please check the file path.${NC}"
    fi
}


# ویرایش تنظیمات سایفون
function edit_local_ip() {
    while true; do
        clear  # صفحه پاک شود
        echo -e "${CYAN}**Enter the port of the settings you want to edit (or press Enter to exit):${NC}"
        read edit_port

        # اگر کاربر اینتر بدون وارد کردن مقدار زد، از حلقه خارج شود
        if [ -z "$edit_port" ]; then
            break  # اگر اینتر زده شد، از حلقه خارج می‌شود
        fi

        # فایل مربوط به پورت وارد شده
        instance_file="$instances_dir/psiphon-127.0.0.1-$edit_port"

        # بررسی اینکه آیا فایل برای این پورت وجود دارد
        if [[ ! -f $instance_file ]]; then
            echo -e "${RED}No settings found for port $edit_port.${NC}"
            continue  # اگر فایل پیدا نشد، دوباره از کاربر پورت خواسته شود
        fi

        # نمایش تنظیمات موجود برای پورت وارد شده
        echo -e "${YELLOW}=== Edit Settings for Port $edit_port ===${NC}"
        echo "1) Change Local IP"
        echo "2) Change Port"
        echo "3) Change Country"
        echo "4) Exit"
        echo -e "${YELLOW}==============================${NC}"
        echo "Your choice:"
        read choice

        case $choice in
            1) 
                # تغییر آی‌پی لوکال سایفون
                echo "Enter new local IP (e.g., 127.0.0.2):"
                read new_ip
                if [ -z "$new_ip" ]; then
                    echo -e "${RED}No IP entered. Going back to the menu...${NC}"
                    continue  # اگر کاربر اینتر زد و هیچ آی‌پی وارد نکرد، دوباره از منو شروع شود
                fi
                sudo sed -i "s/^SocksPort .*/SocksPort $new_ip:$edit_port/" $instance_file
                echo -e "${GREEN}Local IP for port $edit_port has been changed to $new_ip.${NC}"
                sudo systemctl reload psiphon
                ;;

            2) 
                # تغییر پورت سایفون
                echo "Enter new port (e.g., 1080):"
                read new_port
                if [ -z "$new_port" ]; then
                    echo -e "${RED}No port entered. Going back to the menu...${NC}"
                    continue  # اگر کاربر اینتر زد و هیچ پورت وارد نکرد، دوباره از منو شروع شود
                fi
                sudo sed -i "s/^SocksPort .*/SocksPort 127.0.0.1:$new_port/" $instance_file
                echo -e "${GREEN}Port for local IP $edit_local_ip has been changed to $new_port.${NC}"
                sudo systemctl reload psiphon
                ;;

            3)
                # تغییر کشور سایفون
                echo "Enter new country code (e.g., fr, it, tr):"
                read new_country
                if [ -z "$new_country" ]; then
                    echo -e "${RED}No country code entered. Going back to the menu...${NC}"
                    continue  # اگر کاربر اینتر زد و هیچ کد کشوری وارد نکرد، دوباره از منو شروع شود
                fi
                sudo sed -i "s/^ExitNodes.*/ExitNodes {$new_country}/" $instance_file
                echo -e "${GREEN}Country for port $edit_port has been changed to $new_country.${NC}"
                sudo systemctl reload psiphon
                ;;

            4)
                # خروج از منو
                echo -e "${GREEN}Exiting the editing menu.${NC}"
                break
                ;;

            *)
                echo -e "${RED}Invalid option, please try again.${NC}"
                ;;
        esac

        # نمایش نتیجه ویرایش برای کاربر
        echo -e "\nChanges have been successfully applied!"
        echo -e "\nPress Enter to return to the menu..."
        read -p "Press Enter to continue: "  # برای برگشت به منو
        if [ -z "$REPLY" ]; then
            break  # اگر اینتر زده شد، از حلقه خارج می‌شود
        fi

    done
}

function show_created_ips() { 
    clear  # Clear the screen
    echo "**Displaying the created IPs and configurations for Psiphon:"

    # Check if Psiphon configuration file exists
    if [[ -f "$PSIPHON_DIR/psiphon3.conf" ]]; then
        # Extract all SocksPort entries
        grep "SocksPort" "$PSIPHON_DIR/psiphon3.conf" | while read line; do
            local ip_port=$(echo $line | awk '{print $2}')
            local country_code="Not Set"  # Default country code if not found
            
            # Find the corresponding ExitNodes line for this SocksPort
            exit_line=$(grep -A 1 "SocksPort $ip_port" "$PSIPHON_DIR/psiphon3.conf" | grep "ExitNodes")
            if [[ -n "$exit_line" ]]; then
                country_code=$(echo $exit_line | awk '{print $2}' | tr -d '{}')
            fi

            # Print the IP, Port, and corresponding country
            echo -e "IP: $ip_port, Country: $country_code"
        done
    else
        echo -e "${RED}Error: Psiphon configuration file not found!${NC}"
    fi

    # Use a loop to make sure user presses Enter to continue
    while true; do
        echo -e "\nPress Enter to return to the menu..."
        read -p "Press Enter to continue: "  # Wait for user input
        if [ -z "$REPLY" ]; then  # Check if user pressed Enter without typing anything
            break  # Exit the loop and return to the menu
        fi
    done
}
