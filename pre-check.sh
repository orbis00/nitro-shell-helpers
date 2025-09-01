#!/bin/bash

# Pre-check script for StackUp deployment
# This script configures the WIZKE_HOST settings in nitrox .env file

set -e

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
CYAN='\033[0;36m'
NC='\033[0m' # No Color

# Function to print colored output
print_info() {
    echo -e "${BLUE}[INFO]${NC} $1"
}

print_success() {
    echo -e "${GREEN}[SUCCESS]${NC} $1"
}

print_warning() {
    echo -e "${YELLOW}[WARNING]${NC} $1"
}

print_error() {
    echo -e "${RED}[ERROR]${NC} $1"
}

print_header() {
    echo -e "${CYAN}========================================${NC}"
    echo -e "${CYAN}$1${NC}"
    echo -e "${CYAN}========================================${NC}"
}

# Function to check if base path exists
check_base_path() {
    local base_path="$1"
    if [ ! -d "$base_path" ]; then
        print_error "Base path does not exist: $base_path"
        print_info "Please run the main stackup script first to clone repositories"
        exit 1
    fi
}

# Function to update nitrox .env file
update_nitrox_env() {
    local base_path="$1"
    local wizke_url="$2"
    local nitrox_env_file="$base_path/nitrox/.env"
    
    if [ ! -f "$nitrox_env_file" ]; then
        print_error "Nitrox .env file not found: $nitrox_env_file"
        print_info "Please ensure nitrox repository is cloned and .env file exists"
        return 1
    fi
    
    print_info "Updating WIZKE_HOST settings in nitrox .env file..."
    
    # Backup the original file
    cp "$nitrox_env_file" "$nitrox_env_file.backup"
    print_info "Created backup: $nitrox_env_file.backup"
    
    # Update or add WIZKE_HOST_INTERNAL
    if grep -q "^# WIZKE_HOST_INTERNAL=" "$nitrox_env_file"; then
        # Uncomment and replace the URL
        sed -i "s|^# WIZKE_HOST_INTERNAL=.*|WIZKE_HOST_INTERNAL=$wizke_url|" "$nitrox_env_file"
        print_success "Updated WIZKE_HOST_INTERNAL in nitrox .env"
    elif grep -q "^WIZKE_HOST_INTERNAL=" "$nitrox_env_file"; then
        # Replace existing uncommented line
        sed -i "s|^WIZKE_HOST_INTERNAL=.*|WIZKE_HOST_INTERNAL=$wizke_url|" "$nitrox_env_file"
        print_success "Updated existing WIZKE_HOST_INTERNAL in nitrox .env"
    else
        # Add new line
        echo "WIZKE_HOST_INTERNAL=$wizke_url" >> "$nitrox_env_file"
        print_success "Added WIZKE_HOST_INTERNAL to nitrox .env"
    fi
    
    # Update or add WIZKE_HOST_EXTERNAL
    if grep -q "^# WIZKE_HOST_EXTERNAL=" "$nitrox_env_file"; then
        # Uncomment and replace the URL
        sed -i "s|^# WIZKE_HOST_EXTERNAL=.*|WIZKE_HOST_EXTERNAL=$wizke_url|" "$nitrox_env_file"
        print_success "Updated WIZKE_HOST_EXTERNAL in nitrox .env"
    elif grep -q "^WIZKE_HOST_EXTERNAL=" "$nitrox_env_file"; then
        # Replace existing uncommented line
        sed -i "s|^WIZKE_HOST_EXTERNAL=.*|WIZKE_HOST_EXTERNAL=$wizke_url|" "$nitrox_env_file"
        print_success "Updated existing WIZKE_HOST_EXTERNAL in nitrox .env"
    else
        # Add new line
        echo "WIZKE_HOST_EXTERNAL=$wizke_url" >> "$nitrox_env_file"
        print_success "Added WIZKE_HOST_EXTERNAL to nitrox .env"
    fi
    
    print_info "Changes made to nitrox .env file:"
    echo -e "${YELLOW}WIZKE_HOST_INTERNAL=$wizke_url${NC}"
    echo -e "${YELLOW}WIZKE_HOST_EXTERNAL=$wizke_url${NC}"
    
    # Show current settings after update
    echo
    print_info "Current WIZKE_HOST settings in nitrox .env:"
    grep "WIZKE_HOST" "$nitrox_env_file" | sed 's/^/  /'
}

# Main function
main() {
    print_header "StackUp Pre-Check Configuration"
    
    # Default base path (same as multi-stackup.sh)
    local base_path="/home/abhijeet-singh/nitro/"
    
    print_info "Using base path: $base_path"
    
    # Check if base path exists
    check_base_path "$base_path"
    
    echo
    print_info "This script will configure the WIZKE_HOST settings for cookie-cutter integration."
    print_info "You need to provide your cookie-cutter local user URL."
    echo
    
    # Show example
    print_warning "Example URL format: ${CYAN}superHeroName-nitrox-cc.getnitro.co.in${NC}"
    print_warning "Replace 'superHeroName' with your actual identifier"
    echo
    
    # Ask for cookie-cutter URL
    while true; do
        echo -n -e "${BLUE}Enter your cookie-cutter local user URL (or 'skip' to skip): ${NC}"
        read -r user_input
        
        if [ "$user_input" = "skip" ] || [ "$user_input" = "SKIP" ]; then
            print_warning "Skipping WIZKE_HOST configuration."
            print_info "Get in touch with the DevOps team to get VPN access for cookie-cutter integration."
            echo
            print_info "You can run this script again later when you have the URL."
            exit 0
        fi
        
        if [ -z "$user_input" ]; then
            print_error "Please enter a valid URL or 'skip' to skip this configuration."
            continue
        fi
        
        # Validate URL format (basic check)
        if [[ "$user_input" =~ ^[a-zA-Z0-9.-]+\.[a-zA-Z]{2,}$ ]]; then
            # Add https:// prefix if not present
            if [[ ! "$user_input" =~ ^https?:// ]]; then
                user_input="https://$user_input"
            fi
            break
        else
            print_error "Invalid URL format. Please enter a valid URL (e.g., superHeroName-nitrox-cc.getnitro.co.in)"
            continue
        fi
    done
    
    echo
    print_info "Using URL: $user_input"
    echo
    
    # Confirm with user
    echo -n -e "${YELLOW}Do you want to update the nitrox .env file with this URL? (y/N): ${NC}"
    read -n 1 -r
    echo
    
    if [[ ! $REPLY =~ ^[Yy]$ ]]; then
        print_warning "Configuration cancelled by user."
        exit 0
    fi
    
    # Update nitrox .env file
    update_nitrox_env "$base_path" "$user_input"
    
    echo
    print_success "Pre-check configuration completed successfully!"
    print_info "Your nitrox application is now configured to work with cookie-cutter."
    print_info "You can now run the main stackup script: ./multi-stackup.sh -y"
    
    # Ask if user wants to continue with stackup
    echo
    echo -n -e "${BLUE}Do you want to run the main stackup script now? (y/N): ${NC}"
    read -n 1 -r
    echo
    
    if [[ $REPLY =~ ^[Yy]$ ]]; then
        print_info "Starting main stackup script..."
        echo
        exec ./multi-stackup.sh -y
    else
        print_info "You can run './multi-stackup.sh -y' manually when ready."
    fi
}

# Show help if requested
if [ "$1" = "-h" ] || [ "$1" = "--help" ]; then
    echo "StackUp Pre-Check Configuration Script"
    echo "====================================="
    echo
    echo "This script configures the WIZKE_HOST settings in nitrox .env file"
    echo "for cookie-cutter integration."
    echo
    echo "Usage: $0"
    echo
    echo "The script will:"
    echo "1. Ask for your cookie-cutter local user URL"
    echo "2. Update nitrox .env file with WIZKE_HOST_INTERNAL and WIZKE_HOST_EXTERNAL"
    echo "3. Optionally run the main stackup script"
    echo
    echo "Example URL format: superHeroName-nitrox-cc.getnitro.co.in"
    echo
    exit 0
fi

# Run main function
main "$@"
