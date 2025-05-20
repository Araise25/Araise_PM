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

# Base directory for araise
ARAISE_DIR="$HOME/.araise"
FORGE_ORG="Araise25"
FORGE_REPO="Araise_PM"

# Create necessary directories
mkdir -p "$ARAISE_DIR/packages"

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
    echo -e "  ${GREEN}araise${NC} ${YELLOW}help${NC}                 ${NC}- Show this help message"
    echo -e "  ${RED}uninstall-araise${NC}             - Uninstall Araise"
    echo -e "${CYAN}------------------------------------------${NC}"
}

# Function to list installed packages
list_packages() {
    echo -e "${BOLD}${MAGENTA}Installed Packages${NC}"
    echo -e "${CYAN}------------------------------------------${NC}"
    
    local installed=false
    for package_dir in "$ARAISE_DIR/packages"/*; do
        if [ -d "$package_dir" ]; then
            local package_name=$(basename "$package_dir")
            echo -e "${GREEN}*${NC} ${BOLD}$package_name${NC}"
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

  if [ "$TYPE" = "extension" ]; then
    install_browser_extension "$PACKAGE" "$PACKAGE_JSON"
  else
    echo "❌ Unsupported package type: $TYPE"
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
    
    if [ ! -d "$package_dir" ]; then
        echo -e "${RED}ERROR: Package ${CYAN}$package_name${RED} not installed!${NC}"
        return 1
    fi
    
    echo -e "${YELLOW}Uninstalling ${CYAN}$package_name${NC}"
    rm -rf "$package_dir"
    echo -e "${GREEN}SUCCESS: Package uninstalled successfully!${NC}"
}
# Function to install browser extensions with all browser options shown
install_browser_extension() {
  PACKAGE=$1
  JSON=$2
  EXT_DIR="$HOME/.araise/extensions/$PACKAGE"
  mkdir -p "$EXT_DIR"

  echo "📦 Installing browser extension: $PACKAGE"

  # Static list of supported browsers
  BROWSERS=("firefox" "chrome" "brave")

  echo "🌐 Supported browsers:"
  for i in "${!BROWSERS[@]}"; do
    echo "  [$((i+1))] ${BROWSERS[$i]}"
  done

  # Ask user for choice
  read -p "🧭 Select the browser to install extension [1-${#BROWSERS[@]}]: " CHOICE
  SELECTED_BROWSER="${BROWSERS[$((CHOICE-1))]}"

  if [ -z "$SELECTED_BROWSER" ]; then
    echo "❌ Invalid selection."
    exit 1
  fi

  # Check if selected browser is installed
  case "$SELECTED_BROWSER" in
        firefox)
      if ! command -v firefox >/dev/null; then
        echo "❌ Firefox is not installed."
        exit 1
      fi

      XPI_URL=$(echo "$JSON" | jq -r ".browsers.firefox.url")
      XPI_PATH="$EXT_DIR/$PACKAGE"

      echo "🌐 Downloading Firefox extension from: $XPI_URL"
      curl -L "$XPI_URL" -o "$XPI_PATH"

      echo "🦊 Launching Firefox to install extension..."
      firefox "$XPI_PATH"
      ;;

    chrome)
      if ! command -v google-chrome >/dev/null; then
        echo "❌ Google Chrome is not installed."
        exit 1
      fi
      REPO=$(echo "$JSON" | jq -r ".browsers.chrome.repo")
      PATH_INSIDE_REPO=$(echo "$JSON" | jq -r ".browsers.chrome.path")
      TMP_DIR=$(mktemp -d)
      echo "🌐 Cloning from $REPO..."
      git clone --depth 1 "$REPO" "$TMP_DIR"
      cp -r "$TMP_DIR/$PATH_INSIDE_REPO"/* "$EXT_DIR"
      rm -rf "$TMP_DIR"
      echo "✅ Extension files copied to: $EXT_DIR"
      google-chrome "chrome://extensions"
      echo "🧠 Load the unpacked extension from: $EXT_DIR"
      ;;
    brave)
      if ! command -v brave-browser >/dev/null; then
        echo "❌ Brave Browser is not installed."
        exit 1
      fi
      REPO=$(echo "$JSON" | jq -r ".browsers.chrome.repo")
      PATH_INSIDE_REPO=$(echo "$JSON" | jq -r ".browsers.chrome.path")
      TMP_DIR=$(mktemp -d)
      echo "🌐 Cloning from $REPO..."
      git clone --depth 1 "$REPO" "$TMP_DIR"
      cp -r "$TMP_DIR/$PATH_INSIDE_REPO"/* "$EXT_DIR"
      rm -rf "$TMP_DIR"
      echo "✅ Extension files copied to: $EXT_DIR"
      brave-browser "chrome://extensions"
      echo "🧠 Load the unpacked extension from: $EXT_DIR"
      ;;
    *)
      echo "❌ Unsupported browser selected."
      exit 1
      ;;
  esac
}



# Function to show available packages with types
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
    # Sort packages alphabetically, case-insensitive, and show with descriptions
    jq -r '.packages | sort_by(.name | ascii_upcase) | .[] | "\u001b[32m* \u001b[1m\(.name)\u001b[0m - \(.description)"' "$packages_file"
    
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
            
            # ✅ This line will now always be visible
            echo -e "${CYAN}Use ${YELLOW}araise available${CYAN} to list available packages${NC}"
            
            return 0
        else
            echo -e "${RED}ERROR: Downloaded file is not valid JSON${NC}"
            rm -f "$temp_file"
        fi
    fi

    echo -e "${RED}✗ Failed to update package registry${NC}"
    return 1
}


# Function to check if package exists in registry
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

# Function to handle package execution or installation
handle_package_execution() {
    local package_name="$1"
    local package_dir="$ARAISE_DIR/packages/$package_name"
    local packages_file="$ARAISE_DIR/packages.json"
    
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

    if [ -d "$package_dir" ]; then
        run_package "$package_name"
    else
        echo -e "${YELLOW}Package ${CYAN}$package_name${YELLOW} found but not installed${NC}"
        if check_user_consent "Would you like to install it?"; then
            install_package "$package_name"
            if [ $? -eq 0 ]; then
                run_package "$package_name"
            fi
        else
            echo -e "${YELLOW}Operation cancelled${NC}"
            return 1
        fi
    fi
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
        install_package "$2" ;;
    "uninstall")
        [ -z "$2" ] && { echo -e "${RED}ERROR: Package name required${NC}"; exit 1; }
        uninstall_package "$2" ;;
    "list") list_packages ;;
    "update") update_packages ;;
    "available") show_available_packages ;;
    "test") run_tests ;;
    *) handle_package_execution "$1" ;;
esac
