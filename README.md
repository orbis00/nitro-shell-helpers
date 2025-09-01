# StackUp - Repository Management and Deployment Tool

StackUp is a powerful shell script tool designed to manage multiple Git repositories and their deployment processes. It automates the process of cloning, updating, and deploying repositories with custom make commands.

## Features

- **Single Repository Management**: Handle individual Git repositories with the main `stackup.sh` script
- **Multi-Repository Support**: Manage multiple repositories defined in a YAML configuration file
- **Smart Git Operations**:
  - Auto-clone repositories if they don't exist
  - Check for uncommitted changes and prompt for commits
  - Switch to main/master branch automatically
  - Pull latest changes if behind remote
- **Environment File Management**: Automatically create `.env` from `.env.sample` if it doesn't exist
- **Final Deployment**: Run `make up` after processing all repositories
- **Comprehensive Logging**: All operations logged to `/var/log/stackup.log`
- **Flexible Make Commands**: Execute custom make targets or commands after repository operations
- **Interactive Interface**: User-friendly prompts and colored output
- **Error Handling**: Comprehensive error checking and user guidance

## Files Structure

```text
stackup/
├── stackup.sh          # Main script for single repository management
├── multi-stackup.sh    # Multi-repository manager with interactive menu
├── pre-check.sh        # Pre-deployment configuration script
├── repos.yaml          # Configuration file for multiple repositories
└── README.md           # This documentation
```

## Getting Started

### 1. Pre-Check Configuration (Recommended)

Before running the main deployment, use the pre-check script to configure cookie-cutter integration:

```bash
./pre-check.sh
```

The pre-check script will:

- Ask for your cookie-cutter local user URL (e.g., `superHeroName-nitrox-cc.getnitro.co.in`)
- Update the nitrox `.env` file with proper WIZKE_HOST settings
- Optionally run the main stackup script

If you don't have a cookie-cutter URL, the script will advise you to contact the DevOps team for VPN access.

### 2. Main Deployment

After pre-check configuration, run the main deployment:

```bash
./multi-stackup.sh -y
```

## New Features

### Environment File Management

- Automatically detects `.env.sample` files in cloned repositories
- Creates `.env` file from `.env.sample` if `.env` doesn't exist
- Skips creation if `.env` already exists

### Final Deployment

- After processing all repositories, runs `make up` in the main directory
- Falls back to `docker-compose up -d` if no Makefile is found but docker-compose.yml exists
- Helps orchestrate the entire stack after all components are ready

### Comprehensive Logging

- All operations logged with timestamps to `/var/log/stackup.log`
- Falls back to local `./stackup.log` if system log directory is not writable
- Includes INFO, SUCCESS, WARNING, and ERROR level messages
- Logs both single repository and multi-repository operations

## Usage

### Single Repository Mode

```bash
# Basic usage - clone/update repository only
./stackup.sh https://github.com/user/repo.git

# With make command
./stackup.sh https://github.com/user/repo.git setup
./stackup.sh https://github.com/user/repo.git deploy
```

### Multi-Repository Mode

```bash
# Use default repos.yaml configuration
./multi-stackup.sh

# Use custom configuration file
./multi-stackup.sh custom-repos.yaml
```

### Configuration File (repos.yaml)

Edit the `repos.yaml` file to define your repositories:

```yaml
repositories:
  - name: "frontend-app"
    url: "https://github.com/your-org/frontend-app.git"
    make_commands:
      - "install"
      - "build"
      - "deploy"
  
  - name: "backend-api"
    url: "https://github.com/your-org/backend-api.git"
    make_commands:
      - "setup"
      - "test"
      - "deploy"
```

## Installation

1. Clone or download the StackUp scripts to your desired directory
2. Make the scripts executable:

   ```bash
   chmod +x stackup.sh
   chmod +x multi-stackup.sh
   ```

3. Edit `repos.yaml` to configure your repositories
4. Run the scripts!

## Dependencies

- **Required**: `git` - for Git operations
- **Optional**: `yq` - for better YAML parsing (will use fallback parser if not available)

### Installing yq (optional)

```bash
# Ubuntu/Debian
sudo apt-get install yq

# Or download from GitHub releases
sudo wget https://github.com/mikefarah/yq/releases/latest/download/yq_linux_amd64 -O /usr/bin/yq
sudo chmod +x /usr/bin/yq
```

## How It Works

### Single Repository Workflow

1. **Check if repository exists locally**
   - If not, clone it
   - If yes, check status

2. **Handle uncommitted changes**
   - Prompt user to commit changes
   - Or proceed without committing

3. **Update repository**
   - Switch to main/master branch
   - Pull latest changes if behind remote

4. **Execute make commands**
   - Run specified make target
   - Or prompt for custom command if no Makefile exists

### Multi-Repository Workflow

1. **Load configuration** from YAML file
2. **Display interactive menu** with available repositories
3. **For each selected repository**:
   - Show available make commands
   - Allow user to select specific commands or run all
   - Execute the single repository workflow
   - Handle `.env` file creation from `.env.sample`
4. **Final deployment**: Run `make up` in the main directory after all repositories are processed
5. **Logging**: All operations are logged to `/var/log/stackup.log` (or local file if no write permissions)

## Examples

### Example 1: Setup Development Environment

```bash
# Configure repos.yaml with your development repositories
./multi-stackup.sh
# Select "Process ALL repositories" to setup entire stack
```

### Example 2: Deploy Specific Service

```bash
# Deploy just the frontend application
./stackup.sh https://github.com/myorg/frontend.git deploy
```

### Example 3: Custom Configuration

Create a production deployment config:

```yaml
# prod-repos.yaml
repositories:
  - name: "production-api"
    url: "git@github.com:myorg/api.git"
    make_commands:
      - "test"
      - "build"
      - "deploy-prod"
```

Then run:

```bash
./multi-stackup.sh prod-repos.yaml
```

## Error Handling

The scripts include comprehensive error handling:

- Git repository validation
- Dependency checking
- File existence verification
- User input validation
- Make command execution status

## Customization

You can customize the scripts by:

1. **Adding new make targets** in your repository Makefiles
2. **Modifying the YAML configuration** to include more repositories
3. **Extending the scripts** with additional Git operations
4. **Adding environment-specific configurations** for different deployment stages

## Troubleshooting

### Common Issues

1. **Permission denied**: Make sure scripts are executable (`chmod +x`)
2. **Git authentication**: Ensure you have proper SSH keys or credentials set up
3. **Make command not found**: Check if the repository has a Makefile or use custom commands
4. **YAML parsing errors**: Verify your YAML syntax or install `yq` for better parsing

### Debug Mode

Add `set -x` at the beginning of scripts to enable debug output.

## Contributing

Feel free to modify and extend these scripts for your specific needs. The scripts are designed to be readable and maintainable.

## License

This project is open source and available under the MIT License.
