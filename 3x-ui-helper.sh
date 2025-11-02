#!/bin/bash

# ==========================================================
# Xray Core Management and 3X-UI Panel Installation Script
# ==========================================================

# Colors
C_RED='\033[0;31m'
C_GREEN='\033[0;32m'
C_YELLOW='\033[0;33m'
C_CYAN='\033[0;36m'
C_BLUE='\033[0;34m'
C_RESET='\033[0m' # No Color

# Detect system architecture for offline installation
detect_arch() {
    ARCH=$(uname -m)
    case "${ARCH}" in
        x86_64 | x64 | amd64) XUI_ARCH="amd64" ;;
        i*86 | x86) XUI_ARCH="386" ;;
        armv8* | armv8 | arm64 | aarch64) XUI_ARCH="arm64" ;;
        armv7* | armv7) XUI_ARCH="armv7" ;;
        armv6* | armv6) XUI_ARCH="armv6" ;;
        armv5* | armv5) XUI_ARCH="armv5" ;;
        s390x) XUI_ARCH="s390x" ;;
        *) XUI_ARCH="amd64" ;;
    esac
    echo -e "${C_YELLOW}System architecture detected: ${ARCH} -> ${XUI_ARCH}${C_RESET}"
}

# Check and install dependencies
check_dependencies() {
    echo -e "${C_YELLOW}--- Checking Dependencies ---${C_RESET}"
    
    local missing_deps=()
    
    # Check unzip
    if ! command -v unzip &> /dev/null; then
        echo -e "${C_RED}✗ unzip is not installed${C_RESET}"
        missing_deps+=("unzip")
    else
        echo -e "${C_GREEN}✓ unzip is installed${C_RESET}"
    fi
    
    # Check wget
    if ! command -v wget &> /dev/null; then
        echo -e "${C_RED}✗ wget is not installed${C_RESET}"
        missing_deps+=("wget")
    else
        echo -e "${C_GREEN}✓ wget is installed${C_RESET}"
    fi
    
    # Check curl
    if ! command -v curl &> /dev/null; then
        echo -e "${C_RED}✗ curl is not installed${C_RESET}"
        missing_deps+=("curl")
    else
        echo -e "${C_GREEN}✓ curl is installed${C_RESET}"
    fi
    
    # Install missing dependencies
    if [ ${#missing_deps[@]} -gt 0 ]; then
        echo -e "${C_YELLOW}The following dependencies are missing: ${missing_deps[*]}${C_RESET}"
        read -p "Do you want to install them? (y/n): " install_choice
        
        if [[ $install_choice == "y" || $install_choice == "Y" ]]; then
            if command -v apt-get &> /dev/null; then
                apt-get update
                apt-get install -y "${missing_deps[@]}"
            elif command -v yum &> /dev/null; then
                yum install -y "${missing_deps[@]}"
            elif command -v dnf &> /dev/null; then
                dnf install -y "${missing_deps[@]}"
            else
                echo -e "${C_RED}Could not automatically install dependencies. Please install manually: ${missing_deps[*]}${C_RESET}"
                return 1
            fi
            
            # Verify installation
            for dep in "${missing_deps[@]}"; do
                if command -v "$dep" &> /dev/null; then
                    echo -e "${C_GREEN}✓ Successfully installed $dep${C_RESET}"
                else
                    echo -e "${C_RED}✗ Failed to install $dep${C_RESET}"
                    return 1
                fi
            done
        else
            echo -e "${C_RED}Dependencies not installed. Some features may not work.${C_RESET}"
            return 1
        fi
    fi
    
    echo -e "${C_GREEN}All dependencies are satisfied.${C_RESET}"
    return 0
}

# 1. Update Xray Core (Download from GitHub)
update_core_github() {
    echo -e "${C_YELLOW}--- 1. Update Xray Core (Download from GitHub) ---${C_RESET}"
    read -p "Please enter the desired Xray core version (e.g., v1.8.8): " CORE_VERSION
    if [[ -z "$CORE_VERSION" ]]; then
        echo -e "${C_RED}Version is empty. Operation cancelled.${C_RESET}"
        return
    fi

    echo -e "${C_GREEN}Starting core update operation...${C_RESET}"

    # Main commands
    x-ui stop
    wget "https://github.com/XTLS/Xray-core/releases/download/${CORE_VERSION}/Xray-linux-64.zip" -O /usr/local/x-ui/xray.zip

    # Check download success
    if [ $? -ne 0 ]; then
        echo -e "${C_RED}Error downloading Xray core version ${CORE_VERSION}. Please ensure the version is correct.${C_RESET}"
        x-ui start
        return
    fi

    unzip -o /usr/local/x-ui/xray.zip -d /usr/local/x-ui/bin
    cd /usr/local/x-ui/bin
    mv xray xray-linux-amd64
    cd ~

    echo -e "${C_GREEN}Xray core successfully updated to version ${CORE_VERSION}.${C_RESET}"
    x-ui start
    echo -e "${C_GREEN}x-ui panel restarted.${C_RESET}"
}

# 2. Update Xray Core (Use local file)
update_core_local() {
    echo -e "${C_YELLOW}--- 2. Update Xray Core (Use local file) ---${C_RESET}"
    LOCAL_CORE_PATH="/root/corefile/Xray-linux-64.zip"

    if [ ! -f "$LOCAL_CORE_PATH" ]; then
        echo -e "${C_RED}Required core file not found at ${LOCAL_CORE_PATH}.${C_RESET}"
        echo -e "${C_YELLOW}Please download Xray-linux-64.zip file from:${C_RESET}"
        echo -e "${C_CYAN}https://github.com/XTLS/Xray-core/releases/${C_RESET}"
        echo -e "${C_YELLOW}And place it in the /root/corefile/ folder.${C_RESET}"
        return
    fi

    echo -e "${C_GREEN}Local core file found. Starting core update operation...${C_RESET}"

    # Main commands
    x-ui stop

    # Copy and replace file in the panel path
    cp "$LOCAL_CORE_PATH" /usr/local/x-ui/xray.zip
    unzip -o /usr/local/x-ui/xray.zip -d /usr/local/x-ui/bin
    cd /usr/local/x-ui/bin

    # The core filename in the zip might be different, we must rename 'xray' to the panel's expected name 'xray-linux-amd64'
    # If 'xray' exists, rename it.
    if [ -f "xray" ]; then
        mv xray xray-linux-amd64
    fi

    cd ~

    echo -e "${C_GREEN}Xray core successfully updated from local file.${C_RESET}"
    x-ui start
    echo -e "${C_GREEN}x-ui panel restarted.${C_RESET}"
}

# 3. Install 3X-UI Panel Online
install_online() {
    echo -e "${C_YELLOW}--- 3. Install 3X-UI Panel Online ---${C_RESET}"
    read -p "Please enter the desired panel version (e.g., 1.9.0): " PANEL_VERSION
    if [[ -z "$PANEL_VERSION" ]]; then
        echo -e "${C_RED}Version is empty. Operation cancelled.${C_RESET}"
        return
    fi

    echo -e "${C_GREEN}Starting online installation of 3X-UI Panel version v${PANEL_VERSION}...${C_RESET}"
    bash <(curl -Ls https://raw.githubusercontent.com/mhsanaei/3x-ui/master/install.sh) v"${PANEL_VERSION}"

    if [ $? -eq 0 ]; then
        echo -e "${C_GREEN}Online panel installation completed successfully.${C_RESET}"
    else
        echo -e "${C_RED}Error running the online installation script.${C_RESET}"
    fi
}

# 4. Install 3X-UI Panel Offline
install_offline() {
    echo -e "${C_YELLOW}--- 4. Install 3X-UI Panel Offline ---${C_RESET}"
    detect_arch # Detect architecture and set XUI_ARCH

    LOCAL_PANEL_FILE="/root/panelfile/x-ui-linux-${XUI_ARCH}.tar.gz"

    if [ ! -f "$LOCAL_PANEL_FILE" ]; then
        echo -e "${C_RED}Required panel file not found at ${LOCAL_PANEL_FILE}.${C_RESET}"
        echo -e "${C_YELLOW}Please download amd64 file from:${C_RESET}"
        echo -e "${C_CYAN}https://github.com/MHSanaei/3x-ui/releases${C_RESET}"
        echo -e "${C_YELLOW}And place it in the /root/panelfile/ folder.${C_RESET}"
        return
    fi

    echo -e "${C_GREEN}Offline panel file found. Starting installation...${C_RESET}"

    # Offline installation commands
    cd /root/

    echo -e "${C_YELLOW}Removing previous installations...${C_RESET}"
    rm -rf x-ui/ /usr/local/x-ui/ /usr/bin/x-ui

    echo -e "${C_YELLOW}Extracting file...${C_RESET}"
    tar zxvf "$LOCAL_PANEL_FILE"

    echo -e "${C_YELLOW}Setting permissions and copying files...${C_RESET}"
    chmod +x x-ui/x-ui x-ui/bin/xray-linux-* x-ui/x-ui.sh
    cp x-ui/x-ui.sh /usr/bin/x-ui
    cp -f x-ui/x-ui.service /etc/systemd/system/

    echo -e "${C_YELLOW}Moving main folder...${C_RESET}"
    mv x-ui/ /usr/local/

    echo -e "${C_YELLOW}Starting service...${C_RESET}"
    systemctl daemon-reload
    systemctl enable x-ui
    systemctl restart x-ui

    if [ $? -eq 0 ]; then
        echo -e "${C_GREEN}Offline panel installation completed successfully. Service status:${C_RESET}"
        systemctl status x-ui | grep Active
    else
        echo -e "${C_RED}Error running offline installation or starting service.${C_RESET}"
    fi
    cd ~ # Return to home folder
}

# ==========================================================
# Main Menu
# ==========================================================
show_menu() {
    # ASCII Art Header
    echo -e "${C_CYAN}=====================================================${C_RESET}"
    echo -e "${C_BLUE}  .-.       ____ _  _ ___  ____ _____   ${C_RESET}"
    echo -e "${C_BLUE} (o o) boo! / ___| | | |/ _ \/ ___|_  _|   ${C_RESET}"
    echo -e "${C_BLUE} | O \     | |  _| |_| | | | \___ \ | |     ${C_RESET}"
    echo -e "${C_BLUE}  \   \    | |_| | _ | |_| |___) || |     ${C_RESET}"
    echo -e "${C_BLUE}   '~~~'    \____|_| |_|\___/|____/ |_|     ${C_RESET}"
    echo -e "${C_CYAN}-----------------------------------------------------${C_RESET}"
    echo -e "${C_BLUE}    install panel 3x-ui && Change Core by GHOST      ${C_RESET}"
    echo -e "${C_CYAN}=====================================================${C_RESET}"
    
    echo -e "1. ${C_YELLOW}Update Xray Core (Download from GitHub)${C_RESET}"
    echo -e "2. ${C_YELLOW}Update Xray Core (Use local file in /root/corefile/)${C_RESET}"
    echo -e "---"
    echo -e "3. ${C_YELLOW}Install 3X-UI Panel Online${C_RESET}"
    echo -e "4. ${C_YELLOW}Install 3X-UI Panel Offline (from /root/panelfile/)${C_RESET}"
    echo -e "---"
    echo -e "5. ${C_RED}Exit${C_RESET}"
    echo -e "${C_CYAN}=====================================================${C_RESET}"
}

main() {
    # Create required folders if they do not exist
    mkdir -p /root/corefile
    mkdir -p /root/panelfile

    # Check dependencies at startup
    check_dependencies

    while true; do
        show_menu
        read -p "Please select an option [1-5]: " choice

        case $choice in
            1) update_core_github ;;
            2) update_core_local ;;
            3) install_online ;;
            4) install_offline ;;
            5) echo -e "${C_GREEN}Exiting. Good luck!${C_RESET}"; exit 0 ;;
            *) echo -e "${C_RED}Invalid choice. Please enter a number between 1 and 5.${C_RESET}" ;;
        esac
        
        echo -e "\n${C_YELLOW}Press Enter to continue...${C_RESET}"
        read -r
    done
}

# Run the main function
main
