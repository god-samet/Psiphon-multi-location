#!/bin/bash

# Color codes for better visual output
CYAN='\033[0;36m'
GREEN='\033[0;32m'
RED='\033[0;31m'
RESET='\033[0m'

# Path to store IP configuration (using file as simple DB)
# مسیر فایل اصلی پیکربندی سایفون
config_file="/etc/psiphon/psiphon.config"

# تابع بررسی نصب سایفون
function check_psiphon_installed() {
    if ! command -v psiphon-tunnel-core-x86_64 &> /dev/null; then
        return 1
    else
        return 0
    fi
}

# نصب سایفون در صورت نیاز
function install_psiphon() {
    if check_psiphon_installed; then
        echo -e "${GREEN}Psiphon is already installed.${RESET}"
    else
        echo -e "${CYAN}Installing Psiphon...${RESET}"
        sudo apt-get install psiphon -y
    fi
}

# حذف سایفون
function uninstall_psiphon() {
    if check_psiphon_installed; then
        echo -e "${CYAN}Uninstalling Psiphon...${RESET}"
        sudo apt-get remove --purge psiphon -y
    else
        echo -e "${RED}Psiphon is not installed.${RESET}"
    fi
}

# تابع بررسی وضعیت اتصال سایفون
function check_psiphon_connection() {
    if ! /etc/psiphon/psiphon-tunnel-core-x86_64 --status | grep -q "connected"; then
        echo -e "${RED}Psiphon is not connected.${RESET}"
    else
        echo -e "${GREEN}Psiphon is connected.${RESET}"
    fi
}

# پیکربندی سایفون با ورودی کاربر
function configure_psiphon() {
    read -p "${CYAN}Enter Local IP address: ${RESET}" local_ip
    read -p "${CYAN}Enter Port number: ${RESET}" port
    read -p "${CYAN}Enter Country (e.g., US, UK, DE): ${RESET}" country

    if [[ -z "$local_ip" || -z "$port" || -z "$country" ]]; then
        echo -e "${RED}All fields are required!${RESET}"
        return
    fi

    # ویرایش فایل پیکربندی سایفون
    echo -e "local_ip=$local_ip" > $config_file
    echo -e "port=$port" >> $config_file
    echo -e "country=$country" >> $config_file

    # اجرای سایفون با فایل پیکربندی
    echo -e "${GREEN}Configuring Psiphon with IP: $local_ip, Port: $port, Country: $country...${RESET}"
    /etc/psiphon/psiphon-tunnel-core-x86_64 -config $config_file
    if [[ $? -eq 0 ]]; then
        echo -e "${GREEN}Psiphon connected successfully!${RESET}"
    else
        echo -e "${RED}Failed to connect Psiphon.${RESET}"
    fi
}

# پینگ کردن آی‌پی برای بررسی سرعت و وضعیت اتصال
function ping_ip() {
    read -p "${CYAN}Enter IP to ping: ${RESET}" ip_to_ping
    ping -c 4 "$ip_to_ping"
}

# ویرایش IP (تغییر کشور یا پورت)
function edit_ip() {
    read -p "${CYAN}Enter IP to edit: ${RESET}" ip_to_edit
    # بررسی وجود IP در فایل پیکربندی
    if grep -q "$ip_to_edit" "$config_file"; then
        read -p "${CYAN}Enter new country (or press Enter to skip): ${RESET}" new_country
        read -p "${CYAN}Enter new port (or press Enter to skip): ${RESET}" new_port
        
        # جایگزینی اطلاعات قدیمی با اطلاعات جدید در فایل پیکربندی
        if [[ -n "$new_country" ]]; then
            sed -i "s/$ip_to_edit.*/$ip_to_edit $new_port $new_country/" "$config_file"
        elif [[ -n "$new_port" ]]; then
            sed -i "s/$ip_to_edit.*/$ip_to_edit $new_port/" "$config_file"
        fi
        echo -e "${GREEN}IP edited successfully!${RESET}"
    else
        echo -e "${RED}IP not found.${RESET}"
    fi
}

# حذف IP
function remove_ip() {
    read -p "${CYAN}Enter IP to remove: ${RESET}" ip_to_remove
    read -p "${CYAN}Enter Port to remove: ${RESET}" port_to_remove

    # بررسی وجود IP و پورت در فایل پیکربندی
    if grep -q "$ip_to_remove $port_to_remove" "$config_file"; then
        # حذف آی‌پی و پورت از فایل پیکربندی
        sed -i "/$ip_to_remove $port_to_remove/d" "$config_file"
        echo -e "${GREEN}IP and Port removed successfully from the config file!${RESET}"
    else
        echo -e "${RED}IP and Port not found in the config file.${RESET}"
    fi
}

# حذف خود اسکریپت
function remove_script() {
    echo -e "${CYAN}Removing the script...${RESET}"
    rm -- "$0"
    echo -e "${GREEN}Script removed successfully!${RESET}"
}

# بررسی اتصال سایفون به پورت مشخص
function check_psiphon_port_connection() {
    read -p "${CYAN}Enter the port to check connection: ${RESET}" port_to_check
    # استفاده از دستور netstat برای بررسی اتصال به پورت
    if netstat -an | grep ":$port_to_check " | grep -q "ESTABLISHED"; then
        echo -e "${GREEN}Psiphon is connected to port $port_to_check.${RESET}"
    else
        echo -e "${RED}No connection on port $port_to_check. Psiphon may not be using this port.${RESET}"
    fi
}
    

# Add this option to the menu
function show_menu() {
    clear
    echo -e "${CYAN}---- Psiphon Proxy Manager ----${RESET}"
    echo -e "${GREEN}1.${RESET} Install Psiphon"
    echo -e "${GREEN}2.${RESET} Uninstall Psiphon"
    echo -e "${GREEN}3.${RESET} Show Proxy List"
    echo -e "${GREEN}4.${RESET} Ping Proxy IP"
    echo -e "${GREEN}5.${RESET} Edit Proxy IP"
    echo -e "${GREEN}6.${RESET} Remove Proxy IP"
    echo -e "${GREEN}7.${RESET} Configure Psiphon"
    echo -e "${GREEN}8.${RESET} Check Psiphon Connection"
    echo -e "${GREEN}9.${RESET} Remove the Script"
    echo -e "${GREEN}10.${RESET} Check Psiphon Port Connection"
    echo -e "${GREEN}11.${RESET} Exit"
    echo -e "${CYAN}Choose an option: ${RESET}"
    read -r option

    case $option in
        1) install_psiphon ;;
        2) uninstall_psiphon ;;
        3) show_ip_list ;;
        4) ping_ip ;;
        5) edit_ip ;;
        6) remove_ip ;;
        7) configure_psiphon ;;
        8) check_psiphon_connection ;;
        9) remove_script ;;
        10) check_psiphon_port_connection ;;  # Add this to menu
        11) exit 0 ;;
        *) echo -e "${RED}Invalid option!${RESET}" ;;
    esac
}

# Start the script
show_menu

