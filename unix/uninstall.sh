#!/bin/bash

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m'

# Base directory for araise
ARAISE_DIR="$HOME/.araise"

printf "${YELLOW}Warning: This will completely remove Araise Package Manager and all installed packages\n${NC}"
printf "${YELLOW}Continue with uninstallation? (Y/n) ${GREEN}[Enter = Y]${YELLOW}: ${NC}"
read -r response

# If response is empty (just Enter) or starts with Y/y, proceed
if [ -z "$response" ] || [[ "$response" =~ ^[Yy] ]]; then
    echo -e "${YELLOW}Uninstalling Araise Package Manager...${NC}"
    
    # Function to remove from PATH in shell config
    remove_from_shell_config() {
        local config_file=$1
        if [ -f "$config_file" ]; then
            # Remove PATH and environment variable entries
            sed -i.bak '/export PATH=.*\.araise/d' "$config_file"
            sed -i.bak '/export ARAISE_ORG/d' "$config_file"
            rm -f "${config_file}.bak"
            echo -e "${GREEN}Removed Araise from $config_file${NC}"
        fi
    }

    # Detect OS and remove accordingly
    case "$(uname -s)" in
        Linux*|Darwin*)
            # Remove from common shell config files
            remove_from_shell_config "$HOME/.bashrc"
            remove_from_shell_config "$HOME/.zshrc"
            remove_from_shell_config "$HOME/.profile"
            remove_from_shell_config "$HOME/.bash_profile"
            ;;
    esac

    # Remove all Araise files and directories
    if [ -d "$ARAISE_DIR" ]; then
        rm -rf "$ARAISE_DIR"
        echo -e "${GREEN}Removed Araise directory and all installed packages${NC}"
    fi

    # Remove from local bin if exists
    if [ -f "/usr/local/bin/araise" ]; then
        sudo rm -f "/usr/local/bin/araise"
        echo -e "${GREEN}Removed Araise from /usr/local/bin${NC}"
    fi

    # Remove man page if exists
    if [ -f "$HOME/.local/share/man/man1/araise.1.gz" ]; then
        rm -f "$HOME/.local/share/man/man1/araise.1.gz"
        mandb --user-db >/dev/null 2>&1
        echo -e "${GREEN}Removed Araise man page${NC}"
    fi

    echo -e "${GREEN}Araise Package Manager has been completely removed from your system${NC}"
    echo -e "${YELLOW}Please restart your terminal for changes to take effect${NC}"
else
    echo -e "${YELLOW}Uninstallation cancelled${NC}"
    exit 0
fi

