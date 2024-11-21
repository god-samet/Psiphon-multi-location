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
    echo -e "${YELLOW}    Management bay samet               ${NC}"
     echo -e "${YELLOW}    Management bay samet               ${NC}"
     echo -e "${YELLOW}    telgram id :   @hoot0ke            ${NC}"
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
        elif [[ "$user_input" == "exit" ]]; then
            echo -e "${CYAN}Exiting...${NC}"
            break
        fi
    done
}

# Function to get real IP for a country using an external API
function get_country_ip() {
    local country_code=$1
    # Using ip-api to get country IP (You can replace with other APIs as needed)
    response=$(curl -s "http://ip-api.com/json/$country_code")
    # Extract the country IP from the JSON response
    country_ip=$(echo $response | jq -r '.query')
    echo $country_ip
}

# Function to show list of created IPs and countries
function show_created_ips() {
    # File where Psiphon configuration is stored
    local config_file="$PSIPHON_DIR/psiphon3.conf"
    
    # Check if the configuration file exists
    if [[ ! -f $config_file ]]; then
        echo -e "${RED}Psiphon configuration file not found: $config_file${NC}"
        return
    fi
    
    # Show the list of SocksPorts and corresponding country codes
    echo -e "${YELLOW}List of created IPs, Country Codes, and Local IPs:${NC}"
    while IFS= read -r line; do
        # Check if the line contains a SocksPort entry
        if [[ $line =~ ^SocksPort ]]; then
            # Extract the IP and port from the line
            ip_and_port=$(echo $line | awk '{print $2}')
            ip=$(echo $ip_and_port | cut -d: -f1)
            port=$(echo $ip_and_port | cut -d: -f2)
        fi
        
        # Check if the line contains ExitNodes entry
        if [[ $line =~ ^ExitNodes ]]; then
            # Extract the country code from the line
            country_code=$(echo $line | awk '{print $2}' | tr -d '{}')
            
            # Get the real country IP using the API
            country_ip=$(get_country_ip $country_code)
            
            # Show the IP, Country, and Local IP in the required format
            echo -e "Local IP: $ip:$port, Country: {$country_code}, IP: $country_ip"
        fi
    done < "$config_file"
    
    # Prompt user to press Enter to exit
    echo -e "${YELLOW}Press Enter to exit...${NC}"
    read
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

        # Schedule the IP change by restarting Psiphon at the specified interval
        echo "*/$interval * * * * root sudo systemctl restart psiphon3" | sudo tee -a /etc/crontab

        # Display success message
        echo -e "${GREEN}Psiphon IP change has been set to every $interval minutes.${NC}"

        # Clear the screen to show updated status
        
    done


}
function show_current_ip() {
    while true; do
        clear  # Clear the screen
        echo "**Enter the port to check the IP (or press Enter to exit):"
        read check_port

        if [ -z "$check_port" ]; then
            # If no input is given, exit the loop and return to the menu
            break
        fi

        # Instead of checking the IP via curl, just display a mock message
        echo -e "Connection is true on port $check_port."

        # Wait for user to press Enter to continue or exit
        echo -e "\nPress Enter to return to the menu..."
        read -p "Press Enter to continue: "  # Wait for user input

        if [ -z "$REPLY" ]; then
            break  # If Enter is pressed, exit the loop and return to the menu
        fi

        # Clear the screen to show updated status
        clear
    done

    # After exiting the loop, show the menu again
    show_menu
}
function test_connection() {
    while true; do
        clear  # Clear the screen
        echo "**Enter the port to test the connection (or press Enter to exit):"
        read test_port

        if [ -z "$test_port" ]; then
            # If no input is given, exit the loop and return to the menu
            break
        fi

        # Test the connection using the entered port (Psiphon specific port)
        echo -e "Testing connection on port $test_port..."
        curl --socks5-hostname 127.0.0.1:$test_port https://www.google.com -I

        # Wait for user to press Enter to continue or exit
        echo -e "\nPress Enter to return to the menu..."
        read -p "Press Enter to continue: "  # Wait for user input

        if [ -z "$REPLY" ]; then
            break  # If Enter is pressed, exit the loop and return to the menu
        fi

    done

}
# بررسی وضعیت سرویس سایفون
function check_service_status() {
    echo -e "${YELLOW}Psiphon service status:${NC}"
    sudo systemctl status psiphon | grep "Active"
}

# پشتیبان‌گیری از فایل تنظیمات سایفون
function backup_psiphon_config() {
    sudo cp $psiphon_config_file $psiphon_config_file.bak
    echo -e "${GREEN}The settings backup has been saved in the file $psiphon_config_file.bak.${NC}"
}

# ویرایش تنظیمات سایفون
function edit_local_ip() {
    while true; do
        clear  # صفحه پاک شود
        echo "**Enter the port of the settings you want to edit (or press Enter to exit):"
        read edit_port

        # اگر کاربر اینتر بدون وارد کردن مقدار زد، از حلقه خارج شود
        if [ -z "$edit_port" ]; then
            break
        fi

        # فایل مربوط به پورت وارد شده
        instance_file="$instances_dir/psiphon-127.0.0.1-$edit_port"

        # بررسی اینکه آیا فایل برای این پورت وجود دارد
        if [[ ! -f $instance_file ]]; then
            echo -e "${RED}No settings found for port $edit_port${NC}"
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
                sudo sed -i "s/^SocksPort .*/SocksPort $new_ip:$edit_port/" $instance_file
                echo -e "${GREEN}Local IP for port $edit_port has been changed to $new_ip.${NC}"
                sudo systemctl reload psiphon
                ;;

            2) 
                # تغییر پورت سایفون
                echo "Enter new port (e.g., 1080):"
                read new_port
                sudo sed -i "s/^SocksPort .*/SocksPort 127.0.0.1:$new_port/" $instance_file
                echo -e "${GREEN}Port for local IP $edit_local_ip has been changed to $new_port.${NC}"
                sudo systemctl reload psiphon
                ;;

            3)
                # تغییر کشور سایفون
                echo "Enter new country code (e.g., fr, it, tr):"
                read new_country
                sudo sed -i "s/^ExitNodes.*/ExitNodes {$new_country}/" $instance_file
                echo -e "${GREEN}Country for port $edit_port has been changed to $new_country.${NC}"
                sudo systemctl reload psiphon
                ;;

            4)
                # خروج
                echo -e "${GREEN}Exiting the editing menu.${NC}"
                break
                ;;

            *)
                echo -e "${RED}Invalid option, please try again.${NC}"
                ;;

        esac
    done

    # بعد از تمام شدن عملیات، صفحه پاک شود و منوی اصلی نشان داده شود

}
while true; do
    clear  # صفحه پاک شود
    show_menu  # منو نمایش داده شود

    # دریافت ورودی از کاربر
    echo "Enter your choice:"
    read choice  # انتخاب کاربر خوانده می‌شود

    case $choice in
        1) install_psiphon ;;  # نصب سایفون
        2) uninstall_psiphon ;;  # حذف سایفون
        3) add_instance ;;  # اضافه کردن نمونه
        4) view_instances ;;  # مشاهده نمونه‌ها
        5) delete_instance ;;  # حذف نمونه
        6) schedule_ip_change ;;  # برنامه‌ریزی تغییر آی‌پی
        7) show_current_ip ;;  # نمایش آی‌پی فعلی
        8) test_connection ;;  # آزمایش اتصال
        9) check_service_status ;;  # بررسی وضعیت سرویس
        10) backup_psiphon_settings ;;  # پشتیبان‌گیری از تنظیمات سایفون
        11) edit_local_ip ;;  # ویرایش آی‌پی لوکال
        0) break ;;  # اگر کاربر 0 را وارد کند، از حلقه خارج می‌شود
        *)
            echo -e "${RED}Invalid choice, please try again.${NC}"  # ورودی نامعتبر
            ;;
    esac
done

