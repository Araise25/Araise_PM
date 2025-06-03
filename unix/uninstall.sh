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
    
    # Function to remove Araise entries from shell config
    remove_from_shell_config() {
        local config_file=$1
        if [ -f "$config_file" ]; then
            # Create a backup of the config file
            cp "$config_file" "${config_file}.bak"
            
            # Remove PATH and environment variable entries
            sed -i '/export PATH=.*\.araise/d' "$config_file"
            sed -i '/export ARAISE_ORG/d' "$config_file"
            
            # Remove all Araise-created aliases
            sed -i '/# Araise Package Manager global aliases for/,/^alias/d' "$config_file"
            sed -i '/^$/d' "$config_file"  # Remove empty lines
            
            echo -e "${GREEN}Removed Araise entries from $config_file${NC}"
        fi
    }

    # List of all possible shell config files
    local shell_configs=(
        "$HOME/.bashrc"
        "$HOME/.zshrc"
        "$HOME/.profile"
        "$HOME/.bash_profile"
        "$HOME/.bash_login"
        "$HOME/.zprofile"
        "/etc/profile"
        "/etc/bash.bashrc"
        "/etc/zsh/zshrc"
    )

    # Remove from all shell configs
    for config in "${shell_configs[@]}"; do
        remove_from_shell_config "$config"
    done

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
    echo -e "${YELLOW}Please restart your terminal or run 'source ~/.bashrc' (or your shell config) for changes to take effect${NC}"
    echo -e "${YELLOW}Note: If you still see Araise aliases, you may need to manually check your shell configuration files${NC}"
else
    echo -e "${YELLOW}Uninstallation cancelled${NC}"
    exit 0
fi

