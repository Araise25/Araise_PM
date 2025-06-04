#!/bin/bash

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
MAGENTA='\033[0;35m'
CYAN='\033[0;36m'
NC='\033[0m'
BOLD='\033[1m'

# System-wide base directory for araise
ARAISE_DIR="$HOME/.araise"
FORGE_ORG="Araise25"
FORGE_REPO="Araise_PM"
ALIASES_FILE="$ARAISE_DIR/aliases.json"

# Create necessary directories
mkdir -p "$ARAISE_DIR/packages"
mkdir -p "$ARAISE_DIR/extensions"
mkdir -p "$ARAISE_DIR/scripts"

# Function to show help
show_help() {
    echo -e "${BOLD}${MAGENTA}Araise Package Manager${NC}"
    echo -e "${CYAN}------------------------------------------${NC}"
    echo -e "${BOLD}Usage:${NC}"
    echo -e "  ${GREEN}araise${NC} ${CYAN}<package>         ${NC}- Run installed package"
    echo -e "  ${GREEN}araise${NC} ${YELLOW}install${NC} ${CYAN}<package>   ${NC}- Install a package"
    echo -e "  ${GREEN}araise${NC} ${YELLOW}uninstall${NC} ${CYAN}<package> ${NC}- Uninstall a package"
    echo -e "  ${GREEN}araise${NC} ${YELLOW}list${NC}                 ${NC}- List installed packages"
    echo -e "  ${GREEN}araise${NC} ${YELLOW}update${NC}               ${NC}- Update package list"
    echo -e "  ${GREEN}araise${NC} ${YELLOW}available${NC}            ${NC}- Show available packages"
    echo -e "  ${GREEN}araise${NC} ${YELLOW}aliases${NC}              ${NC}- List all aliases"
    echo -e "  ${GREEN}araise${NC} ${YELLOW}help${NC}                 ${NC}- Show this help message"
    echo -e "  ${RED}uninstall-araise${NC}             - Uninstall Araise"
    echo -e "${CYAN}------------------------------------------${NC}"
    echo -e "${BOLD}${YELLOW}Alias Support:${NC}"
    echo -e "  Packages can define aliases in packages.json"
    echo -e "  Use aliases as shortcuts to run packages"
    echo -e "  Example: ${GREEN}araise${NC} ${CYAN}ll${NC} might run ${CYAN}list-tools${NC}"
    echo -e "${CYAN}------------------------------------------${NC}"
}

# Function to initialize aliases file
init_aliases_file() {
    if [ ! -f "$ALIASES_FILE" ]; then
        echo '{"aliases": {}}' > "$ALIASES_FILE"
        chmod 644 "$ALIASES_FILE"  # Make it readable by all users
    fi
}

# Function to update aliases from package registry
update_aliases() {
    local packages_file="$ARAISE_DIR/packages.json"
    
    if [ ! -f "$packages_file" ]; then
        return 1
    fi
    
    init_aliases_file
    
    # Create a temporary file for new aliases
    local temp_aliases=$(mktemp)
    echo '{"aliases": {}}' > "$temp_aliases"
    
    # Extract aliases from all packages
    jq -r '.packages[] | select(.aliases != null) | .name as $pkg | .aliases[] | "\($pkg)|\(.)"' "$packages_file" | while IFS='|' read -r package_name alias; do
        if [ -n "$alias" ] && [ -n "$package_name" ]; then
            # Add alias to temp file
            jq --arg alias "$alias" --arg pkg "$package_name" '.aliases[$alias] = $pkg' "$temp_aliases" > "${temp_aliases}.tmp" && mv "${temp_aliases}.tmp" "$temp_aliases"
        fi
    done
    
    # Replace the aliases file with proper permissions
    mv "$temp_aliases" "$ALIASES_FILE"
    chmod 644 "$ALIASES_FILE"  # Make it readable by all users
    
    return 0
}

# Function to resolve alias to package name
resolve_alias() {
    local alias_name="$1"
    
    init_aliases_file
    
    # Check if it's an alias
    local resolved_package=$(jq -r ".aliases[\"$alias_name\"] // empty" "$ALIASES_FILE" 2>/dev/null)
    
    if [ -n "$resolved_package" ]; then
        echo "$resolved_package"
        return 0
    else
        # Return the original name if not an alias
        echo "$alias_name"
        return 1
    fi
}

# Function to list all aliases
list_aliases() {
    echo -e "${BOLD}${MAGENTA}Araise Package Manager Aliases${NC}"
    echo -e "${CYAN}------------------------------------------${NC}"
    
    local shell_config=$(detect_shell_config)
    local found=false
    
    # Extract only Araise-created aliases from shell config
    while IFS= read -r line; do
        if [[ $line =~ ^#\ Araise\ Package\ Manager\ global\ aliases\ for\ (.+)$ ]]; then
            local package_name="${BASH_REMATCH[1]}"
            echo -e "\n${BOLD}${YELLOW}$package_name${NC}"
            found=true
            # Read next line which should be an alias
            read -r next_line
            while [[ $next_line =~ ^alias\ ([^=]+)= ]]; do
                local alias_name="${BASH_REMATCH[1]}"
                echo -e "  ${GREEN}$alias_name${NC}"
                read -r next_line
            done
        fi
    done < "$shell_config"
    
    if [ "$found" = false ]; then
        echo -e "${YELLOW}No Araise aliases installed${NC}"
        echo -e "${CYAN}Use 'araise install <package>' to install packages with aliases${NC}"
    fi
    
    echo -e "${CYAN}------------------------------------------${NC}"
}

# Function to list installed packages
list_packages() {
    echo -e "${BOLD}${MAGENTA}Installed Packages${NC}"
    echo -e "${CYAN}------------------------------------------${NC}"
    
    local installed=false
    
    # List regular packages
    for package_dir in "$ARAISE_DIR/packages"/*; do
        if [ -d "$package_dir" ]; then
            local package_name=$(basename "$package_dir")
            echo -e "${GREEN}*${NC} ${BOLD}$package_name${NC} ${CYAN}(package)${NC}"
            
            # Show aliases for this package if any
            local package_aliases=$(jq -r ".aliases | to_entries[] | select(.value == \"$package_name\") | .key" "$ALIASES_FILE" 2>/dev/null | tr '\n' ' ')
            if [ -n "$package_aliases" ]; then
                echo -e "  ${YELLOW}Aliases:${NC} ${CYAN}$package_aliases${NC}"
            fi
            
            installed=true
        fi
    done
    
    # List extensions
    for ext_dir in "$ARAISE_DIR/extensions"/*; do
        if [ -d "$ext_dir" ]; then
            local ext_name=$(basename "$ext_dir")
            echo -e "${GREEN}*${NC} ${BOLD}$ext_name${NC} ${BLUE}(extension)${NC}"
            
            # Show aliases for this extension if any
            local ext_aliases=$(jq -r ".aliases | to_entries[] | select(.value == \"$ext_name\") | .key" "$ALIASES_FILE" 2>/dev/null | tr '\n' ' ')
            if [ -n "$ext_aliases" ]; then
                echo -e "  ${YELLOW}Aliases:${NC} ${CYAN}$ext_aliases${NC}"
            fi
            
            installed=true
        fi
    done
    
    # List scripts
    for script_dir in "$ARAISE_DIR/scripts"/*; do
        if [ -d "$script_dir" ]; then
            local script_name=$(basename "$script_dir")
            echo -e "${GREEN}*${NC} ${BOLD}$script_name${NC} ${MAGENTA}(script)${NC}"
            
            # Show aliases for this script if any
            local script_aliases=$(jq -r ".aliases | to_entries[] | select(.value == \"$script_name\") | .key" "$ALIASES_FILE" 2>/dev/null | tr '\n' ' ')
            if [ -n "$script_aliases" ]; then
                echo -e "  ${YELLOW}Aliases:${NC} ${CYAN}$script_aliases${NC}"
            fi
            
            installed=true
        fi
    done
    
    if [ "$installed" = false ]; then
        echo -e "${YELLOW}No packages installed yet!${NC}"
    fi
    echo -e "${CYAN}------------------------------------------${NC}"
}

# Function to detect platform
detect_platform() {
    case "$(uname)" in
        "Linux")
            echo "linux"
            ;;
        "Darwin")
            echo "macos"
            ;;
        MINGW*|MSYS*|CYGWIN*)
            echo "windows"
            ;;
        *)
            echo "linux"  # Default to Linux
            ;;
    esac
}

# Function to show progress bar
show_progress() {
    local current=$1
    local total=$2
    local width=60  # Width of the progress bar
    local percentage=$((current * 100 / total))
    local position=$((width * current / total))
    
    printf "\r%2d:%02d [" $((current / 60)) $((current % 60))
    
    # Print the progress bar
    for ((i = 0; i < width; i++)); do
        if [ $i -eq $position ]; then
            printf "${YELLOW}C${NC}"  # Pacman
        elif [ $i -lt $position ]; then
            printf " "  # Eaten dots
        else
            if [ $((i % 3)) -eq 0 ]; then
                printf "${CYAN}o${NC}"  # Dots to be eaten
            else
                printf "${CYAN}-${NC}"  # Spacing between dots
            fi
        fi
    done
    
    printf "] %3d%%" $percentage
    
    if [ "$current" -eq "$total" ]; then
        printf "\n"
    fi
}

# Function to update system-wide aliases
update_system_aliases() {
    local packages_file="$ARAISE_DIR/packages.json"
    local shell_configs=("$HOME/.bashrc" "$HOME/.zshrc" "$HOME/.profile")
    
    if [ ! -f "$packages_file" ]; then
        return 1
    fi
    
    # Extract aliases from all packages
    jq -r '.packages[] | select(.aliases != null) | .name as $pkg | .aliases[] | "\($pkg)|\(.)"' "$packages_file" | while IFS='|' read -r package_name alias; do
        if [ -n "$alias" ] && [ -n "$package_name" ]; then
            # Get the main script name
            local main_script=$(jq -r ".packages[] | select(.name == \"$package_name\") | .main_script // empty" "$packages_file")
            local script_path="$ARAISE_DIR/scripts/$package_name/$main_script"
            
            # Create alias for each shell config
            for config in "${shell_configs[@]}"; do
                if [ -f "$config" ]; then
                    # Remove existing alias if it exists
                    sed -i.bak "/alias $alias=/d" "$config" 2>/dev/null || true
                    # Add new alias pointing directly to the script
                    echo "# Araise Package Manager alias for $package_name" >> "$config"
                    echo "alias $alias='$script_path'" >> "$config"
                    echo -e "${GREEN}Updated alias ${CYAN}$alias${GREEN} in ${YELLOW}$config${NC}"
                fi
            done
        fi
    done
}

# Updated install_package function to handle different package types
install_package() {
    PACKAGE=$1
    REGISTRY_URL="https://raw.githubusercontent.com/Araise25/Araise_PM/main/common/packages.json"
    JSON=$(curl -s "$REGISTRY_URL")

    PACKAGE_JSON=$(echo "$JSON" | jq -r ".packages[] | select(.name == \"$PACKAGE\")")

    if [ -z "$PACKAGE_JSON" ]; then
        echo "❌ Package '$PACKAGE' not found"
        exit 1
    fi

    TYPE=$(echo "$PACKAGE_JSON" | jq -r ".type")

    case "$TYPE" in
        "extension")
            install_browser_extension "$PACKAGE" "$PACKAGE_JSON"
            ;;
        "script")
            install_script "$PACKAGE" "$PACKAGE_JSON"
            ;;
        *)
            echo "❌ Unsupported package type: $TYPE"
            exit 1
            ;;
    esac
    
    # Update aliases after successful installation
    echo -e "${CYAN}Updating aliases...${NC}"
    update_aliases
    update_system_aliases
    
    # Show the new aliases for this package
    local package_aliases=$(echo "$PACKAGE_JSON" | jq -r '.aliases[] // empty')
    if [ -n "$package_aliases" ]; then
        echo -e "${GREEN}New aliases available:${NC}"
        echo "$package_aliases" | while read -r alias; do
            echo -e "  ${CYAN}$alias${NC} -> ${YELLOW}$PACKAGE${NC}"
        done
        echo -e "${YELLOW}Please restart your terminal or run 'source /etc/profile' to use the new aliases${NC}"
    fi
}

# Function to show process control info based on OS
show_process_control_info() {
    echo -e "${CYAN}------------------------------------------${NC}"
    echo -e "${YELLOW}Process Control Information:${NC}"
    
    case "$(uname)" in
        "Darwin")  # macOS
            echo -e "  ${BOLD}• Control + C${NC} - Stop the process"
            echo -e "  ${BOLD}• Control + Z${NC} - Suspend the process"
            ;;
        "Linux")
            echo -e "  ${BOLD}• Ctrl + C${NC} - Stop the process"
            echo -e "  ${BOLD}• Ctrl + Z${NC} - Suspend the process"
            ;;
        *)  # Default case
            echo -e "  ${BOLD}• Ctrl + C${NC} - Stop the process"
            echo -e "  ${BOLD}• Ctrl + Z${NC} - Suspend the process"
            ;;
    esac
    echo -e "${CYAN}------------------------------------------${NC}"
}

# Updated run_package function to handle platform-specific run commands
run_package() {
    local package_name="$1"
    local package_dir="$ARAISE_DIR/packages/$package_name"
    
    if [ ! -d "$package_dir" ]; then
        echo -e "${RED}ERROR: Package ${CYAN}$package_name${RED} not installed!${NC}"
        return 1
    fi
    
    local packages_file="$ARAISE_DIR/packages.json"
    if [ ! -f "$packages_file" ]; then
        echo -e "${RED}ERROR: Package registry not found!${NC}"
        return 1
    fi
    
    # Detect platform
    local platform=$(detect_platform)
    echo -e "${YELLOW}Detected platform: ${CYAN}$platform${NC}"
    
    # Get run commands for the current platform
    local run_commands=$(jq -r ".packages[] | select(.name == \"$package_name\") | .commands.$platform[]" "$packages_file" 2>/dev/null)
    
    # If platform-specific commands not found, try to use generic commands
    if [ -z "$run_commands" ]; then
        run_commands=$(jq -r ".packages[] | select(.name == \"$package_name\") | .commands[]" "$packages_file" 2>/dev/null)
    fi
    
    if [ -z "$run_commands" ]; then
        echo -e "${RED}ERROR: No run commands defined for ${CYAN}$package_name${NC} on $platform"
        return 1
    fi
    
    # Show process control information and ask for confirmation
    show_process_control_info
    echo -e "${YELLOW}Ready to run package: ${CYAN}$package_name${NC}"
    if ! check_user_consent "Continue?"; then
        echo -e "${YELLOW}Operation cancelled${NC}"
        return 1
    fi
    
    echo -e "${YELLOW}Running package: ${CYAN}$package_name${NC}"
    cd "$package_dir" || return 1
    
    # Execute run commands
    while IFS= read -r cmd; do
        if [ -n "$cmd" ]; then
            echo -e "${CYAN}> $cmd${NC}"
            if ! eval "$cmd"; then
                echo -e "${RED}ERROR: Command failed: ${CYAN}$cmd${NC}"
                cd - >/dev/null
                return 1
            fi
        fi
    done <<< "$run_commands"
    
    cd - >/dev/null
    return 0
}

# Function to uninstall a package
uninstall_package() {
    local package_name="$1"
    local package_dir="$ARAISE_DIR/packages/$package_name"
    local ext_dir="$ARAISE_DIR/extensions/$package_name"
    local script_dir="$ARAISE_DIR/scripts/$package_name"
    
    local found=false
    
    if [ -d "$package_dir" ]; then
        echo -e "${YELLOW}Uninstalling package ${CYAN}$package_name${NC}"
        rm -rf "$package_dir"
        found=true
    fi
    
    if [ -d "$ext_dir" ]; then
        echo -e "${YELLOW}Uninstalling extension ${CYAN}$package_name${NC}"
        rm -rf "$ext_dir"
        found=true
    fi
    
    if [ -d "$script_dir" ]; then
        echo -e "${YELLOW}Uninstalling script ${CYAN}$package_name${NC}"
        rm -rf "$script_dir"
        found=true
        
        # Remove global aliases
        remove_global_aliases "$package_name"
    fi
    
    if [ "$found" = false ]; then
        echo -e "${RED}ERROR: Package ${CYAN}$package_name${RED} not installed!${NC}"
        return 1
    fi
    
    echo -e "${GREEN}SUCCESS: Package uninstalled successfully!${NC}"
    echo -e "${YELLOW}Note: You may need to manually check your shell configuration file for any remaining aliases${NC}"
}

# Updated browser extension installer
install_browser_extension() {
    PACKAGE=$1
    JSON=$2
    EXT_DIR="$ARAISE_DIR/extensions/$PACKAGE"
    mkdir -p "$EXT_DIR"
    chmod 755 "$EXT_DIR"  # Make it accessible by all users

    echo "📦 Installing browser extension: $PACKAGE"

    # Detect installed browsers
    BROWSERS=()
    [[ $(command -v firefox) ]] && BROWSERS+=("firefox")
    [[ $(command -v google-chrome) ]] && BROWSERS+=("chrome")
    [[ $(command -v chromium-browser) ]] && BROWSERS+=("chromium")
    [[ $(command -v brave-browser) ]] && BROWSERS+=("brave")

    if [ ${#BROWSERS[@]} -eq 0 ]; then
        echo "❌ No supported browsers found (firefox, chrome, chromium, brave)."
        exit 1
    fi

    echo "🌐 Available browsers:"
    for i in "${!BROWSERS[@]}"; do
        echo "  [$((i+1))] ${BROWSERS[$i]}"
    done

    read -p "🧭 Select the browser to install extension [1-${#BROWSERS[@]}]: " CHOICE
    CHOICE=${CHOICE:-1}
    BROWSER=${BROWSERS[$((CHOICE-1))]}

    case $BROWSER in
        firefox)
            FIREFOX_LINK=$(echo "$JSON" | jq -r ".browsers.firefox.link // empty")
            FIREFOX_REPO=$(echo "$JSON" | jq -r ".browsers.firefox.repo // empty")
            
            if [ -n "$FIREFOX_LINK" ]; then
                echo "🔗 Opening Firefox extension page..."
                if command -v xdg-open >/dev/null; then
                    xdg-open "$FIREFOX_LINK"
                elif command -v open >/dev/null; then
                    open "$FIREFOX_LINK"
                else
                    echo "🌐 Please visit: $FIREFOX_LINK"
                fi
            elif [ -n "$FIREFOX_REPO" ]; then
                echo "📥 Manual Installation Instructions for Firefox:"
                echo "1. Visit the GitHub repository: $FIREFOX_REPO"
                echo "2. Click on 'Code' (green button) and select 'Download ZIP'"
                echo "3. Extract the downloaded ZIP file"
                echo "4. Open Firefox and go to about:debugging"
                echo "5. Click 'This Firefox' on the left sidebar"
                echo "6. Click 'Load Temporary Add-on'"
                echo "7. Navigate to the extracted folder and select the manifest.json file"
                echo "8. The extension should now be installed temporarily"
                echo ""
                echo "🔗 Opening GitHub repository..."
                if command -v xdg-open >/dev/null; then
                    xdg-open "$FIREFOX_REPO"
                elif command -v open >/dev/null; then
                    open "$FIREFOX_REPO"
                else
                    echo "🌐 Please visit: $FIREFOX_REPO"
                fi
            else
                echo "❌ No installation source provided"
                exit 1
            fi
            ;;
        
        chrome|chromium|brave)
            CHROME_LINK=$(echo "$JSON" | jq -r ".browsers.chrome.link // empty")
            CHROME_REPO=$(echo "$JSON" | jq -r ".browsers.chrome.repo // empty")
            
            if [ -n "$CHROME_LINK" ]; then
                echo "🔗 Opening Chrome Web Store..."
                if command -v xdg-open >/dev/null; then
                    xdg-open "$CHROME_LINK"
                elif command -v open >/dev/null; then
                    open "$CHROME_LINK"
                else
                    echo "🌐 Please visit: $CHROME_LINK"
                fi
            elif [ -n "$CHROME_REPO" ]; then
                echo "📥 Manual Installation Instructions for Chrome/Chromium/Brave:"
                echo "1. Visit the GitHub repository: $CHROME_REPO"
                echo "2. Click on 'Code' (green button) and select 'Download ZIP'"
                echo "3. Extract the downloaded ZIP file"
                echo "4. Open Chrome/Chromium/Brave and go to chrome://extensions"
                echo "5. Enable 'Developer mode' in the top right"
                echo "6. Click 'Load unpacked'"
                echo "7. Select the extracted folder"
                echo "8. The extension should now be installed"
                echo ""
                echo "🔗 Opening GitHub repository..."
                if command -v xdg-open >/dev/null; then
                    xdg-open "$CHROME_REPO"
                elif command -v open >/dev/null; then
                    open "$CHROME_REPO"
                else
                    echo "🌐 Please visit: $CHROME_REPO"
                fi
            else
                echo "❌ No installation source provided"
                exit 1
            fi
            ;;
        *)
            echo "❌ Unsupported browser selected."
            exit 1
            ;;
    esac
}

# Function to detect the shell configuration file
detect_shell_config() {
    case "$(basename "$SHELL")" in
        zsh) echo "$HOME/.zshrc" ;;
        bash) echo "$HOME/.bashrc" ;;
        fish) echo "$HOME/.config/fish/config.fish" ;;
        *) echo "$HOME/.profile" ;;
    esac
}

# Function to add global aliases
add_global_aliases() {
    local package_name="$1"
    local script_dir="$ARAISE_DIR/scripts/$package_name"
    local shell_config=$(detect_shell_config)
    local packages_file="$ARAISE_DIR/packages.json"
    
    # Get package information
    local package_json=$(jq -r ".packages[] | select(.name == \"$package_name\")" "$packages_file")
    local aliases=$(echo "$package_json" | jq -r '.aliases[] // empty')
    local main_script=$(echo "$package_json" | jq -r '.main_script // empty')
    
    if [ -z "$aliases" ]; then
        return 0
    fi
    
    # Create a temporary file for the aliases
    local temp_file=$(mktemp)
    
    # Add header comment
    echo "# Araise Package Manager global aliases for $package_name" >> "$temp_file"
    
    # Add each alias
    echo "$aliases" | while read -r alias; do
        if [ -n "$alias" ]; then
            # Create an alias that directly points to the script
            echo "alias $alias='$script_dir/$main_script'" >> "$temp_file"
        fi
    done
    
    # Append to shell config
    cat "$temp_file" >> "$shell_config"
    rm "$temp_file"
    
    echo -e "${GREEN}Added global aliases to ${YELLOW}$shell_config${NC}"
    echo -e "${YELLOW}Please run 'source $shell_config' to use the new aliases${NC}"
}

# Function to remove global aliases
remove_global_aliases() {
    local package_name="$1"
    local shell_config=$(detect_shell_config)
    
    # Remove the alias block for this package
    sed -i "/# Araise Package Manager global aliases for $package_name/,/^alias/d" "$shell_config"
    sed -i "/^$/d" "$shell_config"  # Remove empty lines
    
    echo -e "${GREEN}Removed global aliases for ${CYAN}$package_name${NC} from ${YELLOW}$shell_config${NC}"
}

# Updated install_script function
install_script() {
    PACKAGE=$1
    JSON=$2
    SCRIPT_DIR="$ARAISE_DIR/scripts/$PACKAGE"
    mkdir -p "$SCRIPT_DIR"
    chmod 755 "$SCRIPT_DIR"

    echo "🔧 Installing script: $PACKAGE"

    REPO=$(echo "$JSON" | jq -r ".repo")
    PATH_INSIDE_REPO=$(echo "$JSON" | jq -r ".path // \".\"")

    if [ "$REPO" = "null" ] || [ -z "$REPO" ]; then
        echo "❌ No repository specified for script $PACKAGE"
        exit 1
    fi

    TMP_DIR=$(mktemp -d)
    echo "🌐 Cloning $REPO..."
    
    if ! git clone --depth 1 "$REPO" "$TMP_DIR"; then
        echo "❌ Failed to clone repository"
        rm -rf "$TMP_DIR"
        exit 1
    fi

    # Copy script files
    if [ "$PATH_INSIDE_REPO" = "." ]; then
        cp -r "$TMP_DIR"/* "$SCRIPT_DIR/" 2>/dev/null || cp -r "$TMP_DIR"/.[^.]* "$SCRIPT_DIR/" 2>/dev/null || true
    else
        cp -r "$TMP_DIR/$PATH_INSIDE_REPO"/* "$SCRIPT_DIR/"
    fi
    
    rm -rf "$TMP_DIR"

    # Make all .sh files executable
    find "$SCRIPT_DIR" -name "*.sh" -type f -exec chmod 755 {} \;

    # Ask about global aliases
    if check_user_consent "Would you like to create global aliases for this script?"; then
        add_global_aliases "$PACKAGE"
    fi

    echo "✅ Script $PACKAGE installed successfully to: $SCRIPT_DIR"
}

# Function to show available packages with types and aliases
show_available_packages() {
    echo -e "${BOLD}${MAGENTA}Available Packages${NC}"
    echo -e "${CYAN}------------------------------------------${NC}"
    
    # Always fetch the latest package registry first
    echo -e "${YELLOW}Fetching latest package registry...${NC}"
    if ! update_packages; then
        echo -e "${RED}Failed to fetch package registry${NC}"
        return 1
    fi
    
    local packages_file="$ARAISE_DIR/packages.json"
    
    if [ ! -f "$packages_file" ]; then
        echo -e "${RED}ERROR: Packages file not found!${NC}"
        return 1
    fi
    
    # Verify the JSON file is valid
    if ! jq empty "$packages_file" 2>/dev/null; then
        echo -e "${RED}ERROR: Invalid JSON format in packages.json${NC}"
        return 1
    fi
    
    # Get package count
    local package_count=$(jq '.packages | length' "$packages_file")
    
    if [ "$package_count" -eq 0 ]; then
        echo -e "${YELLOW}Package registry is empty${NC}"
        return 1
    fi

    echo -e "\n${BOLD}Available packages:${NC}"
    # Sort packages alphabetically and show with descriptions, types, and aliases
    jq -r '.packages | sort_by(.name | ascii_upcase) | .[] | 
        "\u001b[32m* \u001b[1m\(.name)\u001b[0m (\(.type)) - \(.description)" + 
        (if .aliases then "\n  \u001b[33mAliases: \u001b[36m" + (.aliases | join(", ")) + "\u001b[0m" else "" end)' "$packages_file"
    
    echo -e "${CYAN}------------------------------------------${NC}"
}

update_packages() {
    echo -e "${MAGENTA}Updating package registry...${NC}"
    echo -e "${CYAN}------------------------------------------${NC}"
    
    mkdir -p "$ARAISE_DIR"
    local target_file="$ARAISE_DIR/packages.json"
    local remote_url="https://raw.githubusercontent.com/Araise25/Araise_PM/main/common/packages.json"
    local temp_file="/tmp/packages.json.tmp"
    local success=false

    if command -v curl &> /dev/null; then
        echo -e "${YELLOW}Using curl to download package registry${NC}"
        curl -fsSL "$remote_url" -o "$temp_file" 2>/tmp/curl_error.log
        [ $? -eq 0 ] && success=true || {
            echo -e "${RED}ERROR: Failed to download package registry${NC}"
            cat /tmp/curl_error.log
        }
    elif command -v wget &> /dev/null; then
        echo -e "${YELLOW}Using wget to download package registry${NC}"
        wget -q -O "$temp_file" "$remote_url" 2>/tmp/wget_error.log
        [ $? -eq 0 ] && success=true || {
            echo -e "${RED}ERROR: Failed to download package registry${NC}"
            cat /tmp/wget_error.log
        }
    else
        echo -e "${RED}Neither curl nor wget is installed. Cannot fetch package registry.${NC}"
        return 1
    fi

    if [ "$success" = true ]; then
        if jq empty "$temp_file" 2>/dev/null; then
            mv "$temp_file" "$target_file"
            echo -e "${GREEN}✓ Package registry updated successfully!${NC}"
            local package_count=$(jq '.packages | length' "$target_file")
            echo -e "${GREEN}Found ${CYAN}$package_count${GREEN} packages in registry${NC}"
            
            # Update aliases after updating packages
            echo -e "${CYAN}Updating aliases...${NC}"
            update_aliases
            update_system_aliases
            local alias_count=$(jq '.aliases | length' "$ALIASES_FILE" 2>/dev/null || echo "0")
            echo -e "${GREEN}Found ${CYAN}$alias_count${GREEN} aliases in registry${NC}"
            
            echo -e "${CYAN}Use ${YELLOW}araise available${CYAN} to list available packages${NC}"
            echo -e "${CYAN}Use ${YELLOW}araise aliases${CYAN} to list available aliases${NC}"
            echo -e "${YELLOW}Please restart your terminal or run 'source /etc/profile' to use the updated aliases${NC}"
            
            return 0
        else
            echo -e "${RED}ERROR: Downloaded file is not valid JSON${NC}"
            rm -f "$temp_file"
        fi
    fi

    echo -e "${RED}✗ Failed to update package registry${NC}"
    return 1
}

# Function to check if package exists in registry (with alias resolution)
check_package_exists() {
    local package_name="$1"
    local packages_file="$ARAISE_DIR/packages.json"
    
    if [ ! -f "$packages_file" ]; then
        return 1
    fi
    
    # Convert package name to uppercase for case-insensitive comparison
    local package_upper=$(echo "$package_name" | tr '[:lower:]' '[:upper:]')
    local package_exists=$(jq -r '.packages[].name' "$packages_file" | tr '[:lower:]' '[:upper:]' | grep -x "$package_upper")
    [ -n "$package_exists" ]
}

# Function to check user response with Y as default
check_user_consent() {
    local prompt="$1"
    echo -e "${GREEN}$prompt (Y/n) (Enter = Y):${NC}"
    read -r response
    # Return 0 (true) if empty or starts with Y/y
    [ -z "$response" ] || [[ "$response" =~ ^[Yy] ]]
}

handle_package_execution() {
    local input_name="$1"
    shift  # Remove the first argument (package/alias name)
    local args=("$@")  # Store remaining arguments
    local packages_file="$ARAISE_DIR/packages.json"
    
    # First, try to resolve the alias
    local resolved_package
    if resolved_package=$(resolve_alias "$input_name"); then
        echo -e "${CYAN}Resolved alias ${YELLOW}$input_name${CYAN} to package ${YELLOW}$resolved_package${NC}"
        local package_name="$resolved_package"
    else
        local package_name="$input_name"
    fi
    
    local package_dir="$ARAISE_DIR/packages/$package_name"
    local ext_dir="$ARAISE_DIR/extensions/$package_name"
    local script_dir="$ARAISE_DIR/scripts/$package_name"
    
    if [ ! -f "$packages_file" ]; then
        echo -e "${YELLOW}Package registry not found${NC}"
        echo -e "${CYAN}Please run '${GREEN}araise update${CYAN}' to update the registry${NC}"
        return 1
    fi
    
    if ! check_package_exists "$package_name"; then
        echo -e "${YELLOW}Package ${CYAN}$package_name${YELLOW} not found in registry${NC}"
        if check_user_consent "Would you like to update the package registry?"; then
            if update_packages; then
                if check_package_exists "$package_name"; then
                    echo -e "${GREEN}Package ${CYAN}$package_name${GREEN} is now available!${NC}"
                    if check_user_consent "Would you like to proceed with installation?"; then
                        install_package "$package_name"
                        return $?
                    else
                        echo -e "${YELLOW}Installation cancelled${NC}"
                        return 1
                    fi
                else
                    echo -e "${RED}Package ${CYAN}$package_name${RED} not found even after update${NC}"
                    return 1
                fi
            else
                echo -e "${RED}Failed to update registry${NC}"
                return 1
            fi
        else
            echo -e "${YELLOW}Operation cancelled${NC}"
            return 1
        fi
    fi

    # Check what type of package is installed and run accordingly
    if [ -d "$package_dir" ]; then
        run_package "$package_name" "${args[@]}"
    elif [ -d "$script_dir" ]; then
        # For scripts, we don't want to pass the package name as an argument
        run_script "$package_name" "${args[@]}"
    elif [ -d "$ext_dir" ]; then
        echo -e "${BLUE}Extension ${CYAN}$package_name${BLUE} is installed${NC}"
        echo -e "${YELLOW}Extensions run in your browser, not from command line${NC}"
    else
        echo -e "${YELLOW}Package ${CYAN}$package_name${YELLOW} found but not installed${NC}"
        if check_user_consent "Would you like to install it?"; then
            install_package "$package_name"
            if [ $? -eq 0 ]; then
                # Try to run it after installation
                if [ -d "$ARAISE_DIR/packages/$package_name" ]; then
                    run_package "$package_name" "${args[@]}"
                elif [ -d "$ARAISE_DIR/scripts/$package_name" ]; then
                    run_script "$package_name" "${args[@]}"
                fi
            fi
        else
            echo -e "${YELLOW}Operation cancelled${NC}"
            return 1
        fi
    fi
}

# Function to run scripts
run_script() {
    local script_name="$1"
    shift  # Remove the script name from arguments
    local script_args=("$@")  # Store remaining arguments
    local script_dir="$ARAISE_DIR/scripts/$script_name"
    
    if [ ! -d "$script_dir" ]; then
        echo -e "${RED}ERROR: Script ${CYAN}$script_name${RED} not installed!${NC}"
        return 1
    fi
    
    local packages_file="$ARAISE_DIR/packages.json"
    if [ ! -f "$packages_file" ]; then
        echo -e "${RED}ERROR: Package registry not found!${NC}"
        return 1
    fi
    
    # Get script information
    local script_json=$(jq -r ".packages[] | select(.name == \"$script_name\")" "$packages_file")
    local main_script=$(echo "$script_json" | jq -r ".main_script // empty")
    local run_command=$(echo "$script_json" | jq -r ".run_command // empty")
    
    cd "$script_dir" || return 1
    
    echo -e "${YELLOW}Running script: ${CYAN}$script_name${NC}"
    
    if [ -n "$run_command" ]; then
        echo -e "${CYAN}> $run_command ${script_args[*]}${NC}"
        eval "$run_command ${script_args[*]}"
    elif [ -n "$main_script" ] && [ -f "$main_script" ]; then
        echo -e "${CYAN}> ./$main_script ${script_args[*]}${NC}"
        # Execute the script with only the actual arguments, not the script name
        exec ./"$main_script" "${script_args[@]}"
    else
        # Look for common script files
        if [ -f "run.sh" ]; then
            echo -e "${CYAN}> ./run.sh ${script_args[*]}${NC}"
            exec ./run.sh "${script_args[@]}"
        elif [ -f "main.py" ]; then
            echo -e "${CYAN}> python main.py ${script_args[*]}${NC}"
            exec python main.py "${script_args[@]}"
        elif [ -f "index.js" ]; then
            echo -e "${CYAN}> node index.js ${script_args[*]}${NC}"
            exec node index.js "${script_args[@]}"
        else
            echo -e "${RED}ERROR: No executable script found${NC}"
            cd - >/dev/null
            return 1
        fi
    fi
    
    cd - >/dev/null
    return 0
}

# Main command handler
if [ $# -eq 0 ]; then
    show_help
    exit 0
fi

case "$1" in
    "help") show_help ;;
    "install") 
        [ -z "$2" ] && { echo -e "${RED}ERROR: Package name required${NC}"; exit 1; }
        # Resolve alias if provided
        if resolved_package=$(resolve_alias "$2"); then
            echo -e "${CYAN}Resolved alias ${YELLOW}$2${CYAN} to package ${YELLOW}$resolved_package${NC}"
            install_package "$resolved_package"
        else
            install_package "$2"
        fi ;;
    "uninstall")
        [ -z "$2" ] && { echo -e "${RED}ERROR: Package name required${NC}"; exit 1; }
        # Resolve alias if provided
        if resolved_package=$(resolve_alias "$2"); then
            echo -e "${CYAN}Resolved alias ${YELLOW}$2${CYAN} to package ${YELLOW}$resolved_package${NC}"
            uninstall_package "$resolved_package"
        else
            uninstall_package "$2"
        fi ;;
    "list") list_packages ;;
    "update") update_packages ;;
    "available") show_available_packages ;;
    "aliases") list_aliases ;;
    "test") run_tests ;;
    "uninstall-araise") uninstall_araise ;;
*) handle_package_execution "$@" ;;
esac