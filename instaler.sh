#!/bin/bash

# Colors for user interface
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[0;33m'
NC='\033[0m'

# Check for root access
if [[ $EUID -ne 0 ]]; then
    echo -e "${RED}This script must be run with root access. Please rerun it with 'sudo'.${NC}"
    exit 1
fi

# Install dependencies
echo -e "${YELLOW}Installing dependencies...${NC}"
apt update && apt install -y tor curl jq netcat cron wget

if [[ $? -eq 0 ]]; then
    echo -e "${GREEN}Dependencies installed successfully.${NC}"
else
    echo -e "${RED}An error occurred while installing dependencies. Please check your network or repositories.${NC}"
    exit 1
fi

# Check and create the configuration directory
instances_dir="/etc/tor/instances"
if [[ ! -d $instances_dir ]]; then
    mkdir -p $instances_dir
    echo -e "${GREEN}Tor configuration directory created: ${instances_dir}${NC}"
fi

# Enable cron service
echo -e "${YELLOW}Enabling cron service...${NC}"
systemctl enable cron
systemctl start cron

# Ensure Tor is installed
if ! command -v tor &> /dev/null; then
    echo -e "${RED}Tor is not installed. Please check manually.${NC}"
    exit 1
fi

# Set ownership and permissions for the Tor directory
chown -R debian-tor:debian-tor $instances_dir
chmod -R 700 $instances_dir

# Download the main Psiphon script from GitHub if it's not already present
script_url="https://raw.githubusercontent.com/god-samet/Psiphon-multi-location/refs/heads/main/Psiphon_samet.sh"
script_name="Psiphon_samet.sh"

if [[ ! -f $script_name ]]; then
    echo -e "${YELLOW}Downloading main Psiphon script from GitHub...${NC}"
    wget -q $script_url -O $script_name

    if [[ $? -eq 0 ]]; then
        echo -e "${GREEN}Psiphon main script downloaded successfully.${NC}"
    else
        echo -e "${RED}Failed to download the Psiphon script. Please check your network or URL.${NC}"
        exit 1
    fi
fi

# Make the Psiphon main script executable
chmod +x $script_name

# Create the tor-samet wrapper script to run the main Psiphon script
echo -e "${YELLOW}Creating the tor-samet wrapper script...${NC}"

cat << 'EOF' > /usr/local/bin/tor-samet
#!/bin/bash

# Path to the Psiphon main script
script_name="Psiphon_samet.sh"

# Check if the Psiphon script exists
if [[ -f $script_name ]]; then
    bash $script_name
else
    echo -e "Psiphon main script (${script_name}) not found. Please make sure this file is in the same directory."
    exit 1
fi
EOF

# Set executable permissions for the tor-samet wrapper script
chmod +x /usr/local/bin/tor-samet

# Clean up the screen
clear

# Execute the Psiphon script
echo -e "${YELLOW}Running the Psiphon script...${NC}"
bash $script_name
