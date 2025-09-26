#!/bin/bash

set -e

# Colors
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

# Default values
DEFAULT_INSTALL_DIR="/usr/local/bin"
SCRIPT_NAME="ask"
REPO_URL="https://raw.githubusercontent.com/TBXark/shell-ask/master/ask.sh"

# Print colored output
print_info() {
    echo -e "${BLUE}ℹ ${NC}$1"
}

print_success() {
    echo -e "${GREEN}✅ ${NC}$1"
}

print_warning() {
    echo -e "${YELLOW}⚠️  ${NC}$1"
}

print_error() {
    echo -e "${RED}❌ ${NC}$1" >&2
}

# Check if command exists
command_exists() {
    command -v "$1" >/dev/null 2>&1
}

# Check dependencies
check_dependencies() {
    print_info "Checking dependencies..."
    
    local missing_deps=()
    
    if ! command_exists curl; then
        missing_deps+=("curl")
    fi
    
    if ! command_exists jq; then
        missing_deps+=("jq")
    fi
    
    if [ ${#missing_deps[@]} -gt 0 ]; then
        print_error "Missing required dependencies: ${missing_deps[*]}"
        echo ""
        echo "Please install them first:"
        echo "  macOS: brew install ${missing_deps[*]}"
        echo "  Ubuntu/Debian: sudo apt-get install ${missing_deps[*]}"
        echo "  CentOS/RHEL: sudo yum install ${missing_deps[*]}"
        exit 1
    fi
    
    print_success "All dependencies are installed"
}

# Get install directory from user
get_install_dir() {
    echo ""
    print_info "Choose installation directory:"
    echo "  Press Enter for default: ${DEFAULT_INSTALL_DIR}"
    echo "  Or type a custom path:"
    read -p "Install directory: " install_dir
    
    # Use default if empty
    if [ -z "$install_dir" ]; then
        install_dir="$DEFAULT_INSTALL_DIR"
    fi
    
    # Expand ~ to home directory
    install_dir="${install_dir/#\~/$HOME}"
    
    echo ""
    print_info "Installing to: $install_dir"
}

# Create directory if it doesn't exist
create_install_dir() {
    if [ ! -d "$install_dir" ]; then
        print_info "Creating directory $install_dir..."
        
        if mkdir -p "$install_dir" 2>/dev/null; then
            print_success "Directory created successfully"
        else
            print_warning "Failed to create directory, trying with sudo..."
            if sudo mkdir -p "$install_dir"; then
                print_success "Directory created with sudo"
                use_sudo=true
            else
                print_error "Failed to create directory $install_dir"
                exit 1
            fi
        fi
    fi
}

# Download and install the script
install_script() {
    local install_path="$install_dir/$SCRIPT_NAME"
    
    print_info "Downloading ask.sh from GitHub..."
    
    # Try to download without sudo first
    if curl -fsSL "$REPO_URL" -o "$install_path" 2>/dev/null; then
        if chmod +x "$install_path" 2>/dev/null; then
            print_success "Installation completed successfully!"
        else
            print_warning "Downloaded but failed to set permissions, trying with sudo..."
            sudo chmod +x "$install_path"
            print_success "Installation completed successfully!"
        fi
    else
        # Try with sudo if direct download failed
        print_warning "Direct download failed, trying with sudo..."
        if sudo curl -fsSL "$REPO_URL" -o "$install_path" && sudo chmod +x "$install_path"; then
            print_success "Installation completed successfully!"
        else
            print_error "Installation failed. Please check your internet connection and try again."
            exit 1
        fi
    fi
}

# Check if the install directory is in PATH
check_path() {
    if [[ ":$PATH:" != *":$install_dir:"* ]]; then
        print_warning "The installation directory '$install_dir' is not in your PATH."
        echo ""
        echo "To use the 'ask' command from anywhere, add this line to your shell profile:"
        echo "  ~/.bashrc (for bash) or ~/.zshrc (for zsh):"
        echo ""
        echo "  export PATH=\"$install_dir:\$PATH\""
        echo ""
        echo "Then reload your shell or run: source ~/.bashrc (or ~/.zshrc)"
    fi
}

# Show usage instructions
show_usage() {
    echo ""
    print_success "🎉 shell-ask has been installed successfully!"
    echo ""
    echo "To get started:"
    echo "  1. Set up your API key:"
    echo "     $SCRIPT_NAME set-config api_key YOUR_API_KEY"
    echo ""
    echo "  2. Try asking a question:"
    echo "     $SCRIPT_NAME \"How to list files in current directory?\""
    echo ""
    echo "  3. For more help:"
    echo "     $SCRIPT_NAME --help"
    echo ""
}

# Main installation process
main() {
    echo ""
    print_info "🚀 shell-ask installer"
    echo ""
    
    check_dependencies
    get_install_dir
    create_install_dir
    install_script
    check_path
    show_usage
}

# Show help
show_help() {
    echo "shell-ask installer"
    echo ""
    echo "Usage: $0 [OPTIONS]"
    echo ""
    echo "Options:"
    echo "  --help    Show this help message"
    echo "  --dir     Install directory (will be prompted if not specified)"
    echo ""
    echo "Interactive installation:"
    echo "  bash <(curl -fsSL https://raw.githubusercontent.com/TBXark/shell-ask/master/install.sh)"
    echo ""
    exit 0
}

# Parse command line arguments
while [[ $# -gt 0 ]]; do
    case $1 in
        --help|-h)
            show_help
            ;;
        --dir)
            install_dir="$2"
            shift 2
            ;;
        *)
            print_error "Unknown option: $1"
            show_help
            ;;
    esac
done

# Run main installation
main