#!/bin/bash

# StackUp Multi-Repository Manager
# This script processes multiple repositories defined in repos.yaml

set -e

# Logging configuration
LOG_FILE="/var/log/stackup.log"
LOG_ENABLED=true

# Ensure log directory exists
setup_logging() {
    if [ "$LOG_ENABLED" = true ]; then
        # Try to use system log directory, but fall back to local if not writable
        if [ -w "/var/log" ] 2>/dev/null || mkdir -p "/var/log" 2>/dev/null; then
            LOG_FILE="/var/log/stackup.log"
        else
            # Use absolute path for local log file to avoid issues when changing directories
            LOG_FILE="$(pwd)/stackup.log"
            echo "Info: Using local log file: $LOG_FILE"
        fi
        touch "$LOG_FILE" 2>/dev/null || {
            # Use absolute path for local log file to avoid issues when changing directories
            LOG_FILE="$(pwd)/stackup.log"
            echo "Info: Using local log file: $LOG_FILE"
        }
    fi
}

# Logging function
log_message() {
    local level="$1"
    local message="$2"
    if [ "$LOG_ENABLED" = true ]; then
        echo "[$(date '+%Y-%m-%d %H:%M:%S')] [$level] $message" >> "$LOG_FILE"
    fi
}

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
CYAN='\033[0;36m'
NC='\033[0m' # No Color

# Function to print colored output
print_header() {
    echo -e "${CYAN}========================================${NC}"
    echo -e "${CYAN}$1${NC}"
    echo -e "${CYAN}========================================${NC}"
}

print_status() {
    echo -e "${BLUE}[INFO]${NC} $1"
    log_message "INFO" "$1"
}

print_success() {
    echo -e "${GREEN}[SUCCESS]${NC} $1"
    log_message "SUCCESS" "$1"
}

print_warning() {
    echo -e "${YELLOW}[WARNING]${NC} $1"
    log_message "WARNING" "$1"
}

print_error() {
    echo -e "${RED}[ERROR]${NC} $1"
    log_message "ERROR" "$1"
}

# Function to run make up in the current directory after all repos are processed
run_final_make_up() {
    print_header "Running Final Make Up"
    
    if [ -f "Makefile" ]; then
        print_status "Found Makefile in current directory, running 'make up'..."
        if make up 2>&1 | tee -a "$LOG_FILE"; then
            print_success "Final 'make up' completed successfully"
        else
            print_warning "Final 'make up' completed with warnings or errors"
        fi
    else
        print_status "No Makefile found in current directory"
        print_status "Checking for docker-compose.yml..."
        
        if [ -f "docker-compose.yml" ] || [ -f "docker-compose.yaml" ]; then
            print_status "Found Docker Compose file, running 'docker-compose up -d'..."
            if docker-compose up -d 2>&1 | tee -a "$LOG_FILE"; then
                print_success "Docker Compose up completed successfully"
            else
                print_warning "Docker Compose up completed with warnings or errors"
            fi
        else
            print_status "No Makefile or docker-compose.yml found. Skipping final setup."
        fi
    fi
}
check_dependencies() {
    local missing_deps=()
    
    if ! command -v git &> /dev/null; then
        missing_deps+=("git")
    fi
    
    if ! command -v yq &> /dev/null; then
        print_warning "yq is not installed. Will attempt to parse YAML manually."
        print_status "For better YAML parsing, install yq: sudo apt-get install yq"
    fi
    
    if [ ${#missing_deps[@]} -ne 0 ]; then
        print_error "Missing required dependencies: ${missing_deps[*]}"
        exit 1
    fi
}

# Simple YAML parser for repos (fallback if yq is not available)
parse_yaml_simple() {
    local yaml_file="$1"
    local repos=()
    local in_repos=false
    local current_repo=""
    local current_url=""
    local current_commands=()
    local in_make_commands=false
    
    while IFS= read -r line; do
        # Remove leading/trailing whitespace
        line=$(echo "$line" | sed 's/^[[:space:]]*//;s/[[:space:]]*$//')
        
        # Skip comments and empty lines
        [[ "$line" =~ ^#.*$ ]] && continue
        [[ -z "$line" ]] && continue
        
        # Check if we're in repositories section
        if [[ "$line" == "repositories:" ]]; then
            in_repos=true
            continue
        fi
        
        if [ "$in_repos" = true ]; then
            # New repository entry
            if [[ "$line" =~ ^-[[:space:]]*name:[[:space:]]*\"(.*)\"$ ]]; then
                # Save previous repo if exists
                if [ -n "$current_repo" ] && [ -n "$current_url" ]; then
                    repos+=("$current_repo|$current_url|${current_commands[*]}")
                fi
                
                current_repo="${BASH_REMATCH[1]}"
                current_url=""
                current_commands=()
                in_make_commands=false
            elif [[ "$line" =~ ^url:[[:space:]]*\"(.*)\"$ ]]; then
                current_url="${BASH_REMATCH[1]}"
                in_make_commands=false
            elif [[ "$line" == "make_commands:" ]]; then
                in_make_commands=true
            elif [ "$in_make_commands" = true ] && [[ "$line" =~ ^-[[:space:]]*\"(.*)\".*$ ]]; then
                # Extract command name (remove comments)
                local cmd="${BASH_REMATCH[1]}"
                current_commands+=("$cmd")
            fi
        fi
    done < "$yaml_file"
    
    # Save last repo
    if [ -n "$current_repo" ] && [ -n "$current_url" ]; then
        repos+=("$current_repo|$current_url|${current_commands[*]}")
    fi
    
    printf '%s\n' "${repos[@]}"
}

# Function to parse YAML and get repositories
get_repositories() {
    local config_file="$1"
    
    if [ ! -f "$config_file" ]; then
        print_error "Configuration file not found: $config_file"
        exit 1
    fi
    
    if command -v yq &> /dev/null; then
        # Check yq version and use appropriate syntax
        if yq --version 2>&1 | grep -q "mikefarah"; then
            # New yq (mikefarah version)
            yq eval '.repositories[] | .name + "|" + .url + "|" + (.make_commands // [] | join(" "))' "$config_file"
        else
            # Old yq or different version - fall back to manual parsing
            parse_yaml_simple "$config_file"
        fi
    else
        # Fallback to simple parser
        parse_yaml_simple "$config_file"
    fi
}

# Function to display repository menu
show_repository_menu() {
    local repos=("$@")
    local operation_text="Process"
    
    # Check if last argument is operation type
    if [[ "${repos[-1]}" =~ ^(STOP|REMOVE)$ ]]; then
        case "${repos[-1]}" in
            "STOP") operation_text="Stop" ;;
            "REMOVE") operation_text="Remove" ;;
        esac
        # Remove operation indicator from repos array
        unset 'repos[-1]'
    fi
    
    print_header "Available Repositories"
    echo "0) $operation_text ALL repositories"
    
    local i=1
    for repo_info in "${repos[@]}"; do
        IFS='|' read -r name url commands <<< "$repo_info"
        echo "$i) $name ($url)"
        i=$((i + 1))
    done
    
    echo "q) Quit"
    echo
}

# Function to show make commands menu
show_make_commands_menu() {
    local commands_str="$1"
    local repo_name="$2"
    
    if [ -z "$commands_str" ]; then
        print_warning "No predefined make commands for $repo_name"
        return 1
    fi
    
    IFS=' ' read -ra commands <<< "$commands_str"
    
    print_header "Available Make Commands for $repo_name"
    echo "0) Run ALL commands in sequence"
    
    local i=1
    for cmd in "${commands[@]}"; do
        echo "$i) make $cmd"
        i=$((i + 1))
    done
    
    echo "c) Enter custom command"
    echo "s) Skip make commands"
    echo
}

# Function to process a single repository
process_repository() {
    local repo_name="$1"
    local repo_url="$2"
    local make_commands="$3"
    local base_path="$4"
    local branch="$5"
    local auto_mode="$6"
    
    print_header "Processing: $repo_name"
    
    # Change to base path for repository operations
    local original_dir="$(pwd)"
    cd "$base_path"
    
    # First, clone/update the repository without make commands
    print_status "Running: $original_dir/stackup.sh $repo_url"
    "$original_dir/stackup.sh" "$repo_url"
    
    # Then run make commands if make_commands are defined
    if [ -n "$make_commands" ]; then
        IFS=' ' read -ra commands <<< "$make_commands"
        
        # Run ALL commands in sequential order
        if [ ${#commands[@]} -gt 0 ]; then
            print_status "Running ${#commands[@]} make command(s) in sequence: ${commands[*]}"
            for cmd in "${commands[@]}"; do
                print_status "Executing: $original_dir/stackup.sh $repo_url $cmd"
                if "$original_dir/stackup.sh" "$repo_url" "$cmd"; then
                    print_success "Command '$cmd' completed successfully"
                else
                    print_error "Command '$cmd' failed - stopping execution for $repo_name"
                    cd "$original_dir"
                    return 1
                fi
            done
            print_success "All make commands completed for $repo_name"
        else
            print_warning "No commands found to execute"
        fi
    else
        print_status "No make commands defined for this repository"
    fi
    
    # Return to original directory
    cd "$original_dir"
}


# Function to process repository down operation
process_repository_down() {
    local repo_name="$1"
    local base_path="$2"
    local auto_mode="$3"
    
    print_header "Stopping containers for: $repo_name"
    
    local repo_path="$base_path/$repo_name"
    if [ ! -d "$repo_path" ]; then
        print_warning "Repository directory not found: $repo_path"
        return 0
    fi
    
    cd "$repo_path"
    
    # Check if Makefile exists and has down target
    if [ -f "Makefile" ]; then
        if grep -q "^down:" Makefile; then
            print_status "Running 'make down' for $repo_name..."
            if make down 2>&1 | tee -a "$LOG_FILE"; then
                print_success "Successfully stopped containers for $repo_name"
            else
                print_error "Failed to stop containers for $repo_name"
                return 1
            fi
        else
            print_warning "No 'down' target found in Makefile for $repo_name"
        fi
    elif [ -f "docker-compose.yml" ] || [ -f "docker-compose.yaml" ]; then
        print_status "Running 'docker compose down' for $repo_name..."
        if docker compose down 2>&1 | tee -a "$LOG_FILE"; then
            print_success "Successfully stopped containers for $repo_name"
        else
            print_error "Failed to stop containers for $repo_name"
            return 1
        fi
    else
        print_warning "No Makefile or docker-compose file found for $repo_name"
    fi
    
    cd "$base_path"
}

# Function to process repository removal operation
process_repository_remove() {
    local repo_name="$1"
    local base_path="$2"
    local auto_mode="$3"
    
    print_header "Removing containers and data for: $repo_name"
    
    local repo_path="$base_path/$repo_name"
    if [ ! -d "$repo_path" ]; then
        print_warning "Repository directory not found: $repo_path"
        return 0
    fi
    
    cd "$repo_path"
    
    # First stop containers with volumes
    if [ -f "Makefile" ]; then
        if grep -q "^down:" Makefile; then
            print_status "Running 'make down' with volumes for $repo_name..."
            if make down 2>&1 | tee -a "$LOG_FILE"; then
                print_success "Successfully stopped containers for $repo_name"
            else
                print_warning "Failed to stop containers for $repo_name, continuing..."
            fi
        fi
    elif [ -f "docker-compose.yml" ] || [ -f "docker-compose.yaml" ]; then
        print_status "Running 'docker compose down -v' for $repo_name..."
        if docker compose down -v 2>&1 | tee -a "$LOG_FILE"; then
            print_success "Successfully stopped containers and removed volumes for $repo_name"
        else
            print_warning "Failed to stop containers for $repo_name, continuing..."
        fi
    fi
    
    cd "$base_path"
    
    # Ask for confirmation before removing directory (unless auto mode)
    if [ "$auto_mode" = false ]; then
        echo -n "Remove repository directory '$repo_path'? [y/N]: "
        read -r confirm
        if [[ ! "$confirm" =~ ^[Yy]$ ]]; then
            print_status "Directory removal cancelled for $repo_name"
            return 0
        fi
    fi
    
    # Remove the repository directory
    print_status "Removing repository directory: $repo_path"
    if rm -rf "$repo_path"; then
        print_success "Successfully removed repository directory for $repo_name"
    else
        print_error "Failed to remove repository directory for $repo_name"
        return 1
    fi
}

# Main function
main() {
    setup_logging
    print_header "StackUp Multi-Repository Manager"
    log_message "INFO" "Multi-StackUp started with arguments: $*"

    local auto_mode=false
    local config_file="repos.yaml"
    local base_path=""
    local operation="up"  # Default operation

    # Parse command line arguments
    while [[ $# -gt 0 ]]; do
        case $1 in
            down)
                operation="down"
                shift
                ;;
            remove)
                operation="remove"
                shift
                ;;
            -y|--yes)
                auto_mode=true
                shift
                ;;
            -p|--path)
                base_path="$2"
                shift 2
                ;;
            -h|--help)
                echo "Usage: $0 [OPERATION] [-y|--yes] [-p|--path <path>] [config_file]"
                echo ""
                echo "Operations:"
                echo "  (default)     Start up all repositories (clone/update and run make commands)"
                echo "  down          Stop all containers using 'make down'"
                echo "  remove        Stop containers, remove volumes, and delete repository directories"
                echo ""
                echo "Options:"
                echo "  -y, --yes     Automatically process all repositories (no interaction)"
                echo "  -p, --path    Base path for all repositories (default: /home/$USER/nitro/)"
                echo "  -h, --help    Show this help message"
                echo ""
                echo "Arguments:"
                echo "  config_file   YAML configuration file (default: repos.yaml)"
                echo ""
                echo "Examples:"
                echo "  $0                        # Start up all repositories (interactive)"
                echo "  $0 -y                     # Start up all repositories (auto mode)"
                echo "  $0 down -y                # Stop all repositories (auto mode)"
                echo "  $0 remove -y              # Remove all repositories (auto mode)"
                echo "  $0 -p /opt/myrepos/ down  # Stop repos in custom path"
                exit 0
                ;;
            *)
                config_file="$1"
                shift
                ;;
        esac
    done

    # Set default base path if not provided
    if [ -z "$base_path" ]; then
        base_path="/home/$USER/nitro/"
    fi
    mkdir -p "$base_path"
    print_status "Using base path: $base_path"
    print_status "Operation mode: $operation"

    check_dependencies
    
    # For up operation, check stackup.sh dependency
    if [ "$operation" = "up" ] && [ ! -f "./stackup.sh" ]; then
        print_error "stackup.sh not found in current directory"
        exit 1
    fi
    
    if [ "$operation" = "up" ]; then
        chmod +x ./stackup.sh
    fi
    
    if [ ! -f "$config_file" ]; then
        print_error "Configuration file not found: $config_file"
        print_status "Please create a repos.yaml file or specify a different config file"
        exit 1
    fi

    print_status "Loading repositories from $config_file..."
    local repos_info=()
    while IFS= read -r line; do
        [[ -n "$line" ]] && repos_info+=("$line")
    done < <(get_repositories "$config_file")
    if [ ${#repos_info[@]} -eq 0 ]; then
        print_error "No repositories found in $config_file"
        exit 1
    fi
    print_success "Found ${#repos_info[@]} repositories"

    # Handle different operations
    case "$operation" in
        "down")
            handle_down_operation "${repos_info[@]}"
            ;;
        "remove")
            handle_remove_operation "${repos_info[@]}"
            ;;
        "up"|*)
            handle_up_operation "${repos_info[@]}"
            ;;
    esac
}

# Handle down operation
handle_down_operation() {
    local repos_info=("$@")
    
    if [ "$auto_mode" = true ]; then
        print_status "Auto mode enabled: Stopping ALL repositories..."
        print_header "Stopping ALL repositories"
        for repo_info in "${repos_info[@]}"; do
            IFS='|' read -r name url commands <<< "$repo_info"
            process_repository_down "$name" "$base_path" "$auto_mode"
            echo
        done
        print_success "All repositories stopped!"
        print_status "Check the full log at: $LOG_FILE"
        return 0
    fi

    # Interactive mode for down
    while true; do
        show_repository_menu "${repos_info[@]}" "STOP"
        echo -n "Select option: "
        read -r choice
        case "$choice" in
            0)
                print_header "Stopping ALL repositories"
                for repo_info in "${repos_info[@]}"; do
                    IFS='|' read -r name url commands <<< "$repo_info"
                    process_repository_down "$name" "$base_path" "$auto_mode"
                    echo
                done
                print_success "All repositories stopped!"
                print_status "Check the full log at: $LOG_FILE"
                break
                ;;
            [1-9]*)
                local repo_index=$((choice - 1))
                if [ $repo_index -ge 0 ] && [ $repo_index -lt ${#repos_info[@]} ]; then
                    local repo_info="${repos_info[$repo_index]}"
                    IFS='|' read -r name url commands <<< "$repo_info"
                    process_repository_down "$name" "$base_path" "$auto_mode"
                    echo
                    echo -n "Stop another repository? (y/N): "
                    read -r continue_choice
                    [[ ! "$continue_choice" =~ ^[Yy]$ ]] && break
                else
                    print_error "Invalid selection"
                fi
                ;;
            q|Q)
                print_status "Goodbye!"
                exit 0
                ;;
            *)
                print_error "Invalid selection"
                ;;
        esac
    done
}

# Handle remove operation
handle_remove_operation() {
    local repos_info=("$@")
    
    # Safety warning for remove operation
    print_warning "DESTRUCTIVE OPERATION: This will stop containers, remove volumes, and delete repository directories!"
    
    if [ "$auto_mode" = false ]; then
        echo -n "Are you sure you want to continue? [y/N]: "
        read -r confirm
        if [[ ! "$confirm" =~ ^[Yy]$ ]]; then
            print_status "Operation cancelled"
            exit 0
        fi
    fi
    
    if [ "$auto_mode" = true ]; then
        print_status "Auto mode enabled: Removing ALL repositories..."
        print_header "Removing ALL repositories"
        for repo_info in "${repos_info[@]}"; do
            IFS='|' read -r name url commands <<< "$repo_info"
            process_repository_remove "$name" "$base_path" "$auto_mode"
            echo
        done
        print_success "All repositories removed!"
        print_status "Check the full log at: $LOG_FILE"
        return 0
    fi

    # Interactive mode for remove
    while true; do
        show_repository_menu "${repos_info[@]}" "REMOVE"
        echo -n "Select option: "
        read -r choice
        case "$choice" in
            0)
                print_header "Removing ALL repositories"
                echo -n "This will remove ALL repository directories. Continue? [y/N]: "
                read -r final_confirm
                if [[ "$final_confirm" =~ ^[Yy]$ ]]; then
                    for repo_info in "${repos_info[@]}"; do
                        IFS='|' read -r name url commands <<< "$repo_info"
                        process_repository_remove "$name" "$base_path" true  # Force auto mode for batch removal
                        echo
                    done
                    print_success "All repositories removed!"
                else
                    print_status "Operation cancelled"
                fi
                print_status "Check the full log at: $LOG_FILE"
                break
                ;;
            [1-9]*)
                local repo_index=$((choice - 1))
                if [ $repo_index -ge 0 ] && [ $repo_index -lt ${#repos_info[@]} ]; then
                    local repo_info="${repos_info[$repo_index]}"
                    IFS='|' read -r name url commands <<< "$repo_info"
                    process_repository_remove "$name" "$base_path" "$auto_mode"
                    echo
                    echo -n "Remove another repository? (y/N): "
                    read -r continue_choice
                    [[ ! "$continue_choice" =~ ^[Yy]$ ]] && break
                else
                    print_error "Invalid selection"
                fi
                ;;
            q|Q)
                print_status "Goodbye!"
                exit 0
                ;;
            *)
                print_error "Invalid selection"
                ;;
        esac
    done
}

# Handle up operation (original functionality)
handle_up_operation() {
    local repos_info=("$@")
    
    # Prompt for branch (default: main)
    local branch="main"
    if [ "$auto_mode" = false ]; then
        read -p "Enter branch to use for all repositories [main]: " branch_input
        branch="${branch_input:-main}"
    fi
    print_status "Using branch: $branch"

    # Auto mode: process all repositories without interaction
    if [ "$auto_mode" = true ]; then
        print_status "Auto mode enabled: Processing ALL repositories..."
        print_header "Processing ALL repositories"
        for repo_info in "${repos_info[@]}"; do
            IFS='|' read -r name url commands <<< "$repo_info"
            process_repository "$name" "$url" "$commands" "$base_path" "$branch" "$auto_mode"
            echo
        done
        print_success "All repositories processed!"
        echo
        run_final_make_up
        echo
        print_success "StackUp multi-repository operation completed!"
        print_status "Check the full log at: $LOG_FILE"
        return 0
    fi

    # Interactive mode
    while true; do
        show_repository_menu "${repos_info[@]}"
        echo -n "Select option: "
        read -r choice
        case "$choice" in
            0)
                print_header "Processing ALL repositories"
                for repo_info in "${repos_info[@]}"; do
                    IFS='|' read -r name url commands <<< "$repo_info"
                    process_repository "$name" "$url" "$commands" "$base_path" "$branch" "$auto_mode"
                    echo
                done
                print_success "All repositories processed!"
                echo
                run_final_make_up
                echo
                print_success "StackUp multi-repository operation completed!"
                print_status "Check the full log at: $LOG_FILE"
                break
                ;;
            [1-9]*)
                local repo_index=$((choice - 1))
                if [ $repo_index -ge 0 ] && [ $repo_index -lt ${#repos_info[@]} ]; then
                    local repo_info="${repos_info[$repo_index]}"
                    IFS='|' read -r name url commands <<< "$repo_info"
                    process_repository "$name" "$url" "$commands" "$base_path" "$branch" "$auto_mode"
                    echo
                    echo -n "Process another repository? (y/N): "
                    read -r continue_choice
                    [[ ! "$continue_choice" =~ ^[Yy]$ ]] && break
                else
                    print_error "Invalid selection"
                fi
                ;;
            q|Q)
                print_status "Goodbye!"
                exit 0
                ;;
            *)
                print_error "Invalid selection"
                ;;
        esac
    done
}

# Run main function with all arguments
main "$@"
