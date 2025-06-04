#!/usr/bin/env sh

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m'

# Default base directory and bin directory
ARAISE_DIR="$HOME/.araise"
BIN_DIR="$HOME/.local/bin"
MAN_DIR="$HOME/.local/share/man/man1"

FORGE_ORG="Araise25"
FORGE_REPO="Araise_PM"

# Parse arguments
while [ "$#" -gt 0 ]; do
    case "$1" in
        --local-path)
            shift
            if [ -z "$1" ]; then
                echo -e "${RED}Error: --local-path requires a value${NC}"
                exit 1
            fi
            BIN_DIR="$1/bin"
            MAN_DIR="$1/share/man/man1"
            ARAISE_DIR="$1/.araise"
            ;;
    esac
    shift
done

# Function to detect the shell configuration file
detect_shell_config() {
    case "$(basename "$SHELL")" in
        zsh) echo "$HOME/.zshrc" ;;
        bash) echo "$HOME/.bashrc" ;;
        fish) echo "$HOME/.config/fish/config.fish" ;;
        *) echo "$HOME/.profile" ;;
    esac
}

# Function to get CLI scripts
get_cli_scripts() {
    local cli_url="https://raw.githubusercontent.com/${FORGE_ORG}/${FORGE_REPO}/main"
    local success=false

    echo -e "${YELLOW}Downloading CLI scripts from repository...${NC}"
    if command -v curl &> /dev/null; then
        if curl -fsSL "${cli_url}/unix/cli.sh" > "$ARAISE_DIR/cli.sh"; then
            success=true
        fi
    elif command -v wget &> /dev/null; then
        if wget -q -O "$ARAISE_DIR/cli.sh" "${cli_url}/unix/cli.sh"; then
            success=true
        fi
    else
        echo -e "${RED}Error: Neither curl nor wget is installed${NC}"
        return 1
    fi

    if [ "$success" = true ]; then
        return 0
    else
        echo -e "${RED}Error: Failed to download CLI scripts${NC}"
        return 1
    fi
}

# Function to update packages.json
update_packages_json() {
    local packages_file="$ARAISE_DIR/packages.json"
    local remote_url="https://raw.githubusercontent.com/$FORGE_ORG/$FORGE_REPO/main/common/packages.json"
    
    echo -e "${YELLOW}Downloading package registry...${NC}"
    if command -v curl &> /dev/null; then
        curl -fsSL "$remote_url" > "$packages_file" && return 0
    elif command -v wget &> /dev/null; then
        wget -q -O "$packages_file" "$remote_url" && return 0
    fi
    echo -e "${RED}Failed to download package registry${NC}"
    return 1
}

install_unix() {
    # Create required directories
    mkdir -p "$ARAISE_DIR"
    mkdir -p "$BIN_DIR"
    mkdir -p "$MAN_DIR"

    echo -e "${YELLOW}Installing Araise Package Manager...${NC}"

    if ! get_cli_scripts; then
        exit 1
    fi

    if ! update_packages_json; then
        echo '{"packages":[]}' > "$ARAISE_DIR/packages.json"
    fi

    chmod +x "$ARAISE_DIR/cli.sh"

    # Download and install man page
    echo "Installing man page..."
    local man_url="https://raw.githubusercontent.com/$FORGE_ORG/$FORGE_REPO/main/unix/araise.1"
    if command -v curl &> /dev/null; then
        curl -fsSL "$man_url" > "$MAN_DIR/araise.1"
    elif command -v wget &> /dev/null; then
        wget -q -O "$MAN_DIR/araise.1" "$man_url"
    fi

    if [ -f "$MAN_DIR/araise.1" ]; then
        gzip -f "$MAN_DIR/araise.1" >/dev/null 2>&1
        export MANPATH="$MAN_DIR:$MANPATH"
        if command -v mandb >/dev/null 2>&1; then
            mandb --user-db >/dev/null 2>&1
        fi
        echo -e "${GREEN}Man page installed successfully${NC}"
    else
        echo -e "${YELLOW}Warning: Failed to install man page${NC}"
    fi


    ln -sf "$ARAISE_DIR/cli.sh" "$BIN_DIR/araise"

    SHELL_CONFIG=$(detect_shell_config)
    if [ -n "$SHELL_CONFIG" ]; then
        if ! grep -q "$BIN_DIR" "$SHELL_CONFIG" 2>/dev/null; then
            echo "export PATH=\"\$PATH:$BIN_DIR\"" >> "$SHELL_CONFIG"
        fi
        if ! grep -q "MANPATH.*/share/man" "$SHELL_CONFIG" 2>/dev/null; then
            echo "export MANPATH=\"$MAN_DIR:\$MANPATH\"" >> "$SHELL_CONFIG"
        fi
    fi

    echo '{"packages":{}}' > "$ARAISE_DIR/registry.json"

    echo -e "${GREEN}Araise Package Manager has been installed successfully!${NC}"
    echo -e "${YELLOW}Please restart your terminal or run the following command:${NC}"
    echo -e "  ${GREEN}source $SHELL_CONFIG${NC}"
    echo -e "Run '${GREEN}araise help${NC}' or '${GREEN}man araise${NC}' to get started"
}

install_unix
