#!/bin/bash

# StackUp - Repository Management and Deployment Tool
# Usage: ./stackup.sh <git_repo_url> [make_command]

set -e  # Exit on any error

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
NC='\033[0m' # No Color

# Function to print colored output
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

# Function to handle .env file creation
handle_env_file() {
    local repo_dir="$1"
    cd "$repo_dir"
    
    if [ -f ".env.sample" ] && [ ! -f ".env" ]; then
        print_status "Found .env.sample, creating .env file..."
        cp ".env.sample" ".env"
        print_success ".env file created from .env.sample"
    elif [ -f ".env.sample" ] && [ -f ".env" ]; then
        print_status ".env file already exists, skipping creation"
    fi
    
    cd ..
}

# Function to extract repository name from URL
get_repo_name() {
    local repo_url="$1"
    echo "$(basename "$repo_url" .git)"
}

# Function to check if directory exists and is a git repository
is_git_repo() {
    local dir="$1"
    [ -d "$dir" ] && [ -d "$dir/.git" ]
}

# Function to check git status
check_git_status() {
    local repo_dir="$1"
    cd "$repo_dir"
    
    # Check if there are uncommitted changes
    if ! git diff-index --quiet HEAD --; then
        return 1  # Has uncommitted changes
    fi
    
    # Check if there are untracked files
    if [ -n "$(git ls-files --others --exclude-standard)" ]; then
        return 2  # Has untracked files
    fi
    
    return 0  # Clean working directory
}

# Function to check if local branch is behind remote
is_behind_remote() {
    local repo_dir="$1"
    cd "$repo_dir"
    
    # Fetch latest from remote
    git fetch origin
    
    local local_commit=$(git rev-parse HEAD)
    local remote_commit=$(git rev-parse origin/$(git branch --show-current))
    
    [ "$local_commit" != "$remote_commit" ]
}

# Function to handle git repository operations
handle_git_repo() {
    local repo_url="$1"
    local make_command="$2"
    local repo_name=$(get_repo_name "$repo_url")
    local repo_dir="./$repo_name"
    
    print_status "Processing repository: $repo_name"
    
    # Check if repository directory exists
    if is_git_repo "$repo_dir"; then
        print_status "Repository directory exists: $repo_dir"
        
        cd "$repo_dir"
        
        # Check git status
        print_status "Checking repository status..."
        if ! check_git_status "."; then
            case $? in
                1)
                    print_warning "Repository has uncommitted changes!"
                    git status --short
                    echo
                    read -p "Do you want to commit these changes? (y/N): " -n 1 -r
                    echo
                    if [[ $REPLY =~ ^[Yy]$ ]]; then
                        read -p "Enter commit message: " commit_msg
                        git add .
                        git commit -m "$commit_msg"
                        print_success "Changes committed successfully"
                    else
                        print_warning "Proceeding without committing changes"
                    fi
                    ;;
                2)
                    print_warning "Repository has untracked files!"
                    git ls-files --others --exclude-standard
                    echo
                    read -p "Do you want to add and commit these files? (y/N): " -n 1 -r
                    echo
                    if [[ $REPLY =~ ^[Yy]$ ]]; then
    REPO_URL_ORIG="$1"
    if [[ "$REPO_URL_ORIG" =~ ^git@([^:]+):(.+)$ ]]; then
        REPO_URL="https://${BASH_REMATCH[1]}/${BASH_REMATCH[2]}"
    else
        REPO_URL="$REPO_URL_ORIG"
    fi
    local make_command="$2"
                        git add .
                        git commit -m "$commit_msg"
                        print_success "Untracked files committed successfully"
                    fi
                    ;;
            esac
        fi
        
        # Get current branch
        local current_branch=$(git branch --show-current)
        print_status "Current branch: $current_branch"
        
        # Switch to main/master branch if not already there
        local main_branch=""
        if git show-ref --verify --quiet refs/heads/main; then
            main_branch="main"
        elif git show-ref --verify --quiet refs/heads/master; then
            main_branch="master"
        else
            print_error "No main or master branch found!"
            return 1
        fi
        
        if [ "$current_branch" != "$main_branch" ]; then
            print_status "Switching to $main_branch branch..."
            git checkout "$main_branch"
        fi
        
        # Check if local branch is behind remote
        if is_behind_remote "."; then
            print_status "Local branch is behind remote. Pulling latest changes..."
            git pull origin "$main_branch"
            print_success "Repository updated successfully"
        else
            print_success "Repository is up to date"
        fi
        
        cd ..
    else
        print_status "Cloning repository: $repo_url"
        if git clone "$repo_url"; then
            print_success "Repository cloned successfully"
        else
            print_error "Failed to clone repository"
            return 1
        fi
    fi
    
    # Handle .env file creation
    handle_env_file "$repo_dir"
    
    # Execute make command if provided
    if [ -n "$make_command" ]; then
        print_status "Executing make command: $make_command"
        cd "$repo_dir"
        
        # Check if Makefile exists
        if [ -f "Makefile" ]; then
            if make "$make_command"; then
                print_success "Make command executed successfully"
            else
                print_error "Make command failed"
                return 1
            fi
        else
            print_warning "No Makefile found in repository"
            read -p "Do you want to run a custom command instead? (y/N): " -n 1 -r
            echo
            if [[ $REPLY =~ ^[Yy]$ ]]; then
                read -p "Enter command to run: " custom_command
                if eval "$custom_command"; then
                    print_success "Custom command executed successfully"
                else
                    print_error "Custom command failed"
                    return 1
                fi
            fi
        fi
        cd ..
    fi
    
    print_success "Repository $repo_name processed successfully"
    echo "----------------------------------------"
}

# Main function
main() {
    # Setup logging
    setup_logging
    
    echo "======================================"
    echo "     StackUp - Repository Manager     "
    echo "======================================"
    echo
    
    log_message "INFO" "StackUp started with arguments: $*"
    
    # Check if git is installed
    if ! command -v git &> /dev/null; then
        print_error "Git is not installed. Please install git first."
        exit 1
    fi
    
    # Check arguments
    if [ $# -lt 1 ]; then
        print_error "Usage: $0 <git_repo_url> [make_command]"
        echo "Example: $0 https://github.com/user/repo.git setup"
        exit 1
    fi

    local repo_url="$1"
    local make_command="$2"

    # Validate git URL
    if [[ ! "$repo_url" =~ ^https?://.*\.git$ ]] && [[ ! "$repo_url" =~ ^git@.*\.git$ ]]; then
        print_error "Invalid git repository URL: $repo_url"
        exit 1
    fi

    # Only handle .env and make command (git handled by multi-stackup.sh)
    local repo_name=$(get_repo_name "$repo_url")
    local repo_dir="./$repo_name"

    # Handle git repository operations first
    handle_git_repo "$repo_url" "$make_command"

    print_success "StackUp operation completed!"
}

# Run main function with all arguments
main "$@"
