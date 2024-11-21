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
apt update && apt install -y curl jq netcat cron wget

if [[ $? -eq 0 ]]; then
    echo -e "${GREEN}Dependencies installed successfully.${NC}"
else
    echo -e "${RED}An error occurred while installing dependencies. Please check your network or repositories.${NC}"
    exit 1
fi

# Check and create the configuration directory
instances_dir="/etc/psiphon/instances"
if [[ ! -d $instances_dir ]]; then
    mkdir -p $instances_dir
    echo -e "${GREEN}Psiphon configuration directory created: ${instances_dir}${NC}"
fi

# Enable cron service
echo -e "${YELLOW}Enabling cron service...${NC}"
systemctl enable cron
systemctl start cron

# Download Psiphon binary if not present
psiphon_binary="/usr/local/bin/psiphon"
if [[ ! -f $psiphon_binary ]]; then
    echo -e "${YELLOW}Downloading Psiphon binary...${NC}"
    wget -q "https://example.com/psiphon-client" -O $psiphon_binary

    if [[ $? -eq 0 ]]; then
        echo -e "${GREEN}Psiphon binary downloaded successfully.${NC}"
    else
        echo -e "${RED}Failed to download Psiphon binary. Please check your network or URL.${NC}"
        exit 1
    fi
fi

# Make Psiphon binary executable
chmod +x $psiphon_binary

# Download the main script from GitHub if it's not already present
script_url="https://github.com/god-samet/Psiphon-multi-location/blob/main/Psiphon_samet.sh"
script_name="Psiphon_samet.sh"

if [[ ! -f $script_name ]]; then
    echo -e "${YELLOW}Downloading main script from GitHub...${NC}"
    wget -q $script_url -O $script_name

    if [[ $? -eq 0 ]]; then
        echo -e "${GREEN}Main script downloaded successfully.${NC}"
    else
        echo -e "${RED}Failed to download the main script. Please check your network or URL.${NC}"
        exit 1
    fi
fi

# Make the main script executable
chmod +x $script_name

# Copy the ps-samet wrapper script to /usr/local/bin/
echo -e "${YELLOW}Copying ps-samet script to /usr/local/bin/...${NC}"

cat << 'EOF' > /usr/local/bin/ps-samet
#!/bin/bash

# Path to the main script
script_name="Psiphon_samet.sh"

# Check if the main script exists
if [[ -f $script_name ]]; then
    bash $script_name
else
    echo -e "Main script (${script_name}) not found. Please make sure this file is in the same directory."
    exit 1
fi
EOF

# Set executable permissions for the ps-samet wrapper script
chmod +x /usr/local/bin/ps-samet

# Clean up the screen
clear

# Execute the main script
echo -e "${YELLOW}You can now run the script by typing 'ps-samet'.${NC}"
