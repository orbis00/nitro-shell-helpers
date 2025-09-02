
#!/bin/bash

# StackUp Multi-Repository Manager
# This script processes multiple repositories defined in repos.yaml

set -e

# GitHub repository configuration
GITHUB_BASE_URL="https://raw.githubusercontent.com/orbis00/nitro-shell-helpers/stackup"

# Function to execute script directly from GitHub
execute_remote_script() {
    local script_name="$1"
    shift
    local args=("$@")
    
    print_status "Executing $script_name from GitHub..."
    if curl -s -f "${GITHUB_BASE_URL}/${script_name}?_=${RANDOM}" | bash -s -- "${args[@]}"; then
        return 0
    else
        print_error "Failed to execute $script_name from GitHub"
        return 1
    fi
}

# Function to get repos.yaml content from GitHub
get_remote_repos_yaml() {
    print_status "Loading repositories configuration from GitHub..."
    curl -s -f "${GITHUB_BASE_URL}/repos.yaml?_=${RANDOM}"
}

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

### Integrated pre-check logic (from pre-check.sh)
run_pre_check_local() {
    local base_path="${1:-/home/$USER/nitro/}"
    local user_url="${2:-}" # If provided, non-interactive
    local auto_yes="${3:-false}"

    print_header "StackUp Pre-Check Configuration"
    print_status "Using base path: $base_path"

    update_nitrox_env() {
        local env_file="$base_path/nitrox/.env"
        local url="$1"
        if [ ! -f "$env_file" ]; then
            print_warning ".env file not found at $env_file. Skipping update."
            return 1
        fi
        sed -i "/^WIZKE_HOST=/d" "$env_file"
        echo "WIZKE_HOST=$url" >> "$env_file"
        print_success "Updated WIZKE_HOST in $env_file"
    }

    if [ -n "$user_url" ]; then
        print_status "Non-interactive mode: using provided URL: $user_url"
        update_nitrox_env "$user_url"
        print_success "Pre-check configuration completed successfully!"
        return 0
    fi

    print_status "This script will configure the WIZKE_HOST settings for cookie-cutter integration."
    print_status "You need to provide your cookie-cutter local user URL."
    print_warning "Example URL format: superHeroName-nitrox-cc.getnitro.co.in"
    print_warning "Replace 'superHeroName' with your actual identifier"

    while true; do
        echo -n -e "${BLUE}Enter your cookie-cutter local user URL (or 'skip' to skip): ${NC}"
        read -r user_input
        if [ "$user_input" = "skip" ] || [ "$user_input" = "SKIP" ]; then
            print_warning "Skipping WIZKE_HOST configuration."
            print_status "You can run this script again later when you have the URL."
            return 0
        fi
        if [ -z "$user_input" ]; then
            print_error "Please enter a valid URL or 'skip' to skip this configuration."
            continue
        fi
        if [[ "$user_input" =~ ^[a-zA-Z0-9.-]+\.[a-zA-Z]{2,}$ ]]; then
            if [[ ! "$user_input" =~ ^https?:// ]]; then
                user_input="https://$user_input"
            fi
            break
        else
            print_error "Invalid URL format. Please enter a valid URL (e.g., superHeroName-nitrox-cc.getnitro.co.in)"
            continue
        fi
    done

    print_status "Using URL: $user_input"
    if [ "$auto_yes" = false ]; then
        echo -n -e "${YELLOW}Do you want to update the nitrox .env file with this URL? (y/N): ${NC}"
        read -n 1 -r
        echo
        if [[ ! $REPLY =~ ^[Yy]$ ]]; then
            print_warning "Configuration cancelled by user."
            return 0
        fi
    fi
    update_nitrox_env "$user_input"
    print_success "Pre-check configuration completed successfully!"
    print_status "Your nitrox application is now configured to work with cookie-cutter."
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
    local use_remote=false
    
    # Check if we should use remote repos.yaml
    if [ "$config_file" = "repos.yaml" ] && [ ! -f "$config_file" ]; then
        use_remote=true
    fi
    
    if [ "$use_remote" = true ]; then
        # Get repos.yaml content from GitHub and parse it
        local temp_file=$(mktemp)
        if get_remote_repos_yaml > "$temp_file" 2>/dev/null; then
            parse_yaml_simple "$temp_file"
            rm -f "$temp_file"
        else
            echo "" >&2
            print_error "Failed to load repositories configuration from GitHub" >&2
            exit 1
        fi
    else
        # Use local file
        if [ ! -f "$config_file" ]; then
            echo "" >&2
            print_error "Configuration file not found: $config_file" >&2
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

# Function to check if containers are running and handle restart/skip
check_and_handle_running_containers() {
    local repo_name="$1"
    local base_path="$2"
    local auto_mode="$3"
    
    local repo_path="$base_path/$repo_name"
    if [ ! -d "$repo_path" ]; then
        print_warning "Repository directory not found: $repo_path"
        return 0  # Continue processing
    fi
    
    cd "$repo_path"
    
    # Check for docker-compose file
    local compose_file=""
    if [ -f "docker-compose.yml" ]; then
        compose_file="docker-compose.yml"
    elif [ -f "docker-compose.yaml" ]; then
        compose_file="docker-compose.yaml"
    elif [ -f "compose.yml" ]; then
        compose_file="compose.yml"
    elif [ -f "compose.yaml" ]; then
        compose_file="compose.yaml"
    fi
    
    if [ -n "$compose_file" ]; then
        print_status "Found $compose_file in $repo_name, checking for running containers..."
        
        # Check if any containers from this compose file are running
        local running_containers=$(docker compose ps --services --filter "status=running" 2>/dev/null | wc -l)
        
        if [ "$running_containers" -gt 0 ]; then
            print_warning "Found $running_containers running container(s) for $repo_name"
            
            if [ "$auto_mode" = true ]; then
                print_status "Auto mode: Restarting containers for $repo_name..."
                restart_containers "$compose_file" "$repo_name"
                return 0  # Continue processing
            else
                # Interactive mode: ask user what to do
                echo -n -e "${YELLOW}Containers are already running for $repo_name. Restart (r) or Skip (s)? [r/s]: ${NC}"
                read -n 1 -r choice
                echo
                
                case "$choice" in
                    r|R)
                        print_status "Restarting containers for $repo_name..."
                        restart_containers "$compose_file" "$repo_name"
                        return 0  # Continue processing
                        ;;
                    s|S)
                        print_status "Skipping $repo_name and moving to next repository"
                        return 1  # Skip this repository
                        ;;
                    *)
                        print_status "Invalid choice, defaulting to restart..."
                        restart_containers "$compose_file" "$repo_name"
                        return 0  # Continue processing
                        ;;
                esac
            fi
        else
            print_status "No running containers found for $repo_name"
            return 0  # Continue processing
        fi
    else
        print_status "No docker-compose file found in $repo_name"
        return 0  # Continue processing
    fi
    
    cd "$base_path"
}

# Function to restart containers
restart_containers() {
    local compose_file="$1"
    local repo_name="$2"
    
    print_status "Stopping containers for $repo_name..."
    if docker compose -f "$compose_file" down 2>&1 | tee -a "$LOG_FILE"; then
        print_success "Containers stopped successfully for $repo_name"
        
        print_status "Starting containers for $repo_name..."
        if docker compose -f "$compose_file" up -d 2>&1 | tee -a "$LOG_FILE"; then
            print_success "Containers restarted successfully for $repo_name"
        else
            print_error "Failed to start containers for $repo_name"
        fi
    else
        print_error "Failed to stop containers for $repo_name"
    fi
}

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
    
    # First, clone/update the repository without make commands using remote stackup.sh
    print_status "Running remote stackup.sh for $repo_url"
    execute_remote_script "stackup.sh" "$repo_url"
    
    # Check if containers are already running after cloning/updating
    # This function returns 1 if user chooses to skip, 0 to continue
    if ! check_and_handle_running_containers "$repo_name" "$base_path" "$auto_mode"; then
        print_status "Skipping all commands for $repo_name - moving to next repository"
        cd "$original_dir"
        return 0
    fi
    
    # Then run make commands if make_commands are defined
    if [ -n "$make_commands" ]; then
        IFS=' ' read -ra commands <<< "$make_commands"
        
        # Run ALL commands in sequential order
        if [ ${#commands[@]} -gt 0 ]; then
            print_status "Running ${#commands[@]} make command(s) in sequence: ${commands[*]}"
            for cmd in "${commands[@]}"; do
                print_status "Executing remote stackup.sh: $repo_url $cmd"
                if execute_remote_script "stackup.sh" "$repo_url" "$cmd"; then
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
    local skip_post_precheck=false  # New flag to skip post-deployment pre-check

    # Parse command line arguments
    while [[ $# -gt 0 ]]; do
        case $1 in
            pre-check)
                operation="pre-check"
                shift
                ;;
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
            --skip-post-precheck)
                skip_post_precheck=true
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
                echo "  pre-check     Configure cookie-cutter integration and WIZKE_HOST settings"
                echo "  down          Stop all containers using 'make down'"
                echo "  remove        Stop containers, remove volumes, and delete repository directories"
                echo ""
                echo "Options:"
                echo "  -y, --yes                Automatically process all repositories (no interaction)"
                echo "  --skip-post-precheck     Skip automatic post-deployment pre-check configuration"
                echo "  -p, --path               Base path for all repositories (default: /home/$USER/nitro/)"
                echo "  -h, --help               Show this help message"
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
    
    # Note: Using remote stackup.sh from GitHub, no local file needed
    # Config file can be local or remote (handled by get_repositories function)
    
    # Check if we'll use remote repos.yaml and inform user
    if [ "$config_file" = "repos.yaml" ] && [ ! -f "$config_file" ]; then
        print_status "Local repos.yaml not found, using remote version from GitHub..."
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
        "pre-check")
            handle_precheck_operation
            ;;
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

# Handle pre-check operation
handle_precheck_operation() {
    print_header "StackUp Pre-Check Configuration"
    
    print_status "Starting pre-check configuration for cookie-cutter integration..."
    echo
    
    # Execute remote pre-check.sh script
    if execute_remote_script "pre-check.sh"; then
        print_success "Pre-check configuration completed successfully!"
        echo
        echo -n -e "${BLUE}Do you want to run the main deployment now? (y/N): ${NC}"
        read -n 1 -r
        echo
        if [[ $REPLY =~ ^[Yy]$ ]]; then
            print_status "Starting main deployment..."
            echo
            # Re-run the script with up operation
            exec "$0" -y
        else
            print_status "You can run '$0 -y' manually when ready for deployment."
        fi
    else
        print_error "Pre-check configuration failed"
        exit 1
    fi
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
        run_post_deployment_precheck
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
                run_post_deployment_precheck
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

# Function to execute post-deployment pre-check configuration
run_post_deployment_precheck() {
    # Check if post pre-check is disabled
    if [ "$skip_post_precheck" = true ]; then
        print_status "Post-deployment pre-check skipped (--skip-post-precheck flag used)"
        return 0
    fi
    
    print_header "Post-Deployment Configuration"
    
    print_status "All repositories have been deployed successfully!"
    print_status "Now running pre-check configuration for cookie-cutter integration..."
    echo
    
    # Always run pre-check in interactive mode at the end
    run_pre_check_local "$base_path"
    print_success "Post-deployment configuration completed successfully!"
    echo
    print_status "Your entire stack is now deployed and configured!"
    echo
}

# Run main function with all arguments
main "$@"
