#!/bin/bash
echo "Script Version 0.4.7"
echo "This script is used to facilitate configuration of git for obsidian. "

HOME_PATH="/data/data/com.termux/files/home"
DOWNLOAD_FOLDER="$HOME_PATH/storage/shared/Download"


# Add these variables at the beginning of your script, after the existing variables
LOG_DIR="$HOME_PATH/logs"
CURRENT_DATE=$(date +%Y-%m-%d)
LOG_FILE="$LOG_DIR/$CURRENT_DATE.log"

# Colors for terminal output
RED='\033[0;31m'
GREEN='\033[0;32m'
BLUE='\033[0;34m'
YELLOW='\033[1;33m'
NC='\033[0m' # No Color

# Function to initialize logging
function init_logging() {
    mkdir -p "$LOG_DIR"
    if [ ! -f "$LOG_FILE" ]; then
        touch "$LOG_FILE"
        log_message "INFO" "Started new log file for $CURRENT_DATE"
    fi
}


# Function to log messages and show them to user
function log_message() {
    local level="$1"
    local message="$2"
    local timestamp
    timestamp=$(date '+%Y-%m-%d %H:%M:%S')

    # Write to log file with timestamp
    echo "[$timestamp] [$level] $message" >> "$LOG_FILE"

    # Echo to user without timestamp, but with colors
    case "$level" in
        "ERROR")
            echo -e "${RED}ERROR: $message${NC}"
            ;;
        "SUCCESS")
            echo -e "${GREEN}SUCCESS: $message${NC}"
            ;;
        "INFO")
            echo -e "${BLUE}INFO: $message${NC}"
            ;;
        "OUTPUT")
            echo -e "${YELLOW}$message${NC}"
            ;;
    esac
}

init_logging

# Function to execute command and log its output
function execute_and_log() {
    local command="$1"
    local description="$2"
    local timestamp
    timestamp=$(date '+%Y-%m-%d %H:%M:%S')

    log_message "INFO" "Executing: $description"
    echo "[$timestamp] [COMMAND] $command" >> "$LOG_FILE"
    echo "[$timestamp] [OUTPUT-START]" >> "$LOG_FILE"

    # Execute command and stream output in real-time
    # Use a temporary file to capture exit code
    local exit_file
    exit_file=$(mktemp)

    # Use tee to both display and log output in real-time
    # Wrap the command in a subshell to capture its exit code
    (eval "$command" 2>&1 || echo $? > "$exit_file") | while IFS= read -r line; do
        # Write to log file
        echo "$line" >> "$LOG_FILE"
        # Show output to user with yellow color
        echo -e "${YELLOW}$line${NC}"
    done

    # Get the exit code
    exit_code=0
    if [ -f "$exit_file" ]; then
        exit_code=$(cat "$exit_file")
        rm "$exit_file"
    fi

    echo "[$timestamp] [OUTPUT-END] (Exit Code: $exit_code)" >> "$LOG_FILE"

    return $exit_code
}

function install_required_deps() {
    log_message "INFO" "Starting installation of required dependencies"

    execute_and_log "apt update" "Running apt update"
    execute_and_log "apt upgrade -y" "Running apt upgrade"
    execute_and_log "pkg install openssh -y" "Installing openssh"
    execute_and_log "pkg install git -y" "Installing git"

    log_message "SUCCESS" "Completed installation of required dependencies"
}

function access_storage() {
    log_message "INFO" "Setting up Termux storage access"
    execute_and_log "termux-setup-storage" "Setting up storage access"
}

function configure_git() {
    local name="$1"
    local email="$2"

    log_message "INFO" "Configuring git for user: $name with email: $email"

    execute_and_log "git config --global user.name \"$name\"" "Setting git username"
    execute_and_log "git config --global user.email \"$email\"" "Setting git email"
    execute_and_log "git config --global credential.helper store" "Setting credential helper"
    execute_and_log "git config --global pull.rebase false" "Setting pull strategy"
    execute_and_log "git config --global --add safe.directory '*'" "Setting safe directory"
    execute_and_log "git config --global core.protectNTFS false" "Setting NTFS protection"
    execute_and_log "git config --global core.longpaths true" "Setting long paths"

    log_message "SUCCESS" "Git configuration completed"
}

function generate_ssh_key() {
    local email="$1"
    log_message "INFO" "Generating SSH key for email: $email"

    if [ ! -f $HOME_PATH/.ssh/id_ed25519 ]; then
        if execute_and_log "ssh-keygen -q -t ed25519 -N \"\" -f $HOME_PATH/.ssh/id_ed25519 -C \"$email\"" "Generating SSH key"; then
            log_message "SUCCESS" "Generated new SSH key"
        else
            log_message "ERROR" "Failed to generate SSH key"
            return 1
        fi
    else
        log_message "INFO" "SSH key already exists"
    fi

    log_message "INFO" "Starting ssh-agent"
    execute_and_log "eval \$(ssh-agent -s)" "Starting SSH agent"
    execute_and_log "ssh-add" "Adding SSH key to agent"

    log_message "INFO" "Here is your SSH public key. You can paste it inside Github"
    echo "------------"
    execute_and_log "cat $HOME_PATH/.ssh/id_ed25519.pub" "Reading public key"
    echo "------------"
}

function clone_repo() {
    local folder="$1"
    local git_url="$2"

    log_message "INFO" "Starting repository clone"
    log_message "INFO" "Git Folder: $HOME_PATH/$folder"
    log_message "INFO" "Obsidian Folder: $DOWNLOAD_FOLDER/$folder"
    log_message "INFO" "Git URL: $git_url"

    if ! execute_and_log "cd \"$HOME_PATH/\"" "Changing to home directory"; then
        log_message "ERROR" "Failed to change directory to $HOME_PATH"
        return 1
    fi

    execute_and_log "mkdir -p \"$HOME_PATH/$folder\"" "Creating repository directory"

    if execute_and_log "git --git-dir \"$HOME_PATH/$folder\" --work-tree \"$DOWNLOAD_FOLDER/$folder\" clone \"$git_url\"" "Cloning repository"; then
        log_message "SUCCESS" "Successfully cloned repository"
    else
        log_message "ERROR" "Failed to clone repository"
        return 1
    fi

    if ! execute_and_log "cd \"$HOME_PATH/$folder\"" "Changing to repository directory"; then
        log_message "ERROR" "Failed to change directory to $HOME_PATH/$folder"
        return 1
    fi

    if execute_and_log "git worktree add --checkout \"$DOWNLOAD_FOLDER/$folder\" --force" "Setting up git worktree"; then
        log_message "SUCCESS" "Successfully set up git worktree"
    else
        log_message "ERROR" "Failed to set up git worktree"
        return 1
    fi
}

function add_gitignore_entries() {
    local folder_name="$1"

    if ! execute_and_log "cd \"$DOWNLOAD_FOLDER/$folder_name\"" "Changing to repository directory"; then
        log_message "ERROR" "Failed to change directory to $DOWNLOAD_FOLDER/$folder_name"
        return 1
    fi

    local GITIGNORE=".gitignore"
    local ENTRIES=".trash/
    .obsidian/workspace
    .obsidian/workspace.json
    .obsidian/workspace-mobile.json"

    if [ ! -f "$GITIGNORE" ]; then
        execute_and_log "touch $GITIGNORE" "Creating .gitignore file"
    fi

    log_message "INFO" "Adding entries to .gitignore"
    for entry in $ENTRIES; do
        if ! grep -q -Fx "$entry" "$GITIGNORE"; then
            execute_and_log "echo \"$entry\" >> $GITIGNORE" "Adding $entry to .gitignore"
        fi
    done

    log_message "SUCCESS" "Updated .gitignore file"
}

function add_gitattributes_entry() {
    local folder_name="$1"

    if ! execute_and_log "cd \"$DOWNLOAD_FOLDER/$folder_name\"" "Changing to repository directory"; then
        log_message "ERROR" "Failed to change directory to $DOWNLOAD_FOLDER/$folder_name"
        return 1
    fi

    local GITATTRIBUTES=".gitattributes"
    local ENTRY="*.md merge=union"

    if [ ! -f "$GITATTRIBUTES" ]; then
        execute_and_log "touch $GITATTRIBUTES" "Creating .gitattributes file"
    fi

    if ! grep -q -F "$ENTRY" "$GITATTRIBUTES"; then
        execute_and_log "echo \"$ENTRY\" >> $GITATTRIBUTES" "Adding merge=union entry"
    fi

    log_message "SUCCESS" "Updated .gitattributes file"
}

function remove_files_from_git() {
    local folder_name="$1"

    log_message "INFO" "Removing specified files from git tracking"

    if ! execute_and_log "cd \"$DOWNLOAD_FOLDER/$folder_name\"" "Changing to repository directory"; then
        log_message "ERROR" "Failed to change directory to $DOWNLOAD_FOLDER/$folder_name"
        return 1
    fi

    local FILES=".obsidian/workspace
    .obsidian/workspace.json
    .obsidian/workspace-mobile.json"

    for file in $FILES; do
        if [ -f "$file" ]; then
            if ! execute_and_log "cd \"$HOME_PATH/$folder_name\"" "Changing to git directory"; then
                log_message "ERROR" "Failed to change directory to $HOME_PATH/$folder_name"
                return 1
            fi
            execute_and_log "git rm -f --cached \"$DOWNLOAD_FOLDER/$folder_name/$file\"" "Removing $file from git"
            log_message "SUCCESS" "Removed $file from git tracking"
        fi
    done

    if ! execute_and_log "cd \"$HOME_PATH/$folder_name\"" "Changing to git directory"; then
        log_message "ERROR" "Failed to change directory to $HOME_PATH/$folder_name"
        return 1
    fi

    if [[ $(git status --porcelain) ]]; then
        execute_and_log "git commit -am \"Remove ignored files\"" "Committing removed files"
    fi
}

function write_to_file_if_not_exists() {
    local content="$1"
    local file="$2"

    if [ ! -f "$file" ]; then
        execute_and_log "touch \"$file\"" "Creating file $file"
        log_message "SUCCESS" "Created file $file"
    fi

    if ! grep -qxF "$content" "$file"; then
        execute_and_log "echo \"$content\" >> \"$file\"" "Adding content to $file"
        log_message "SUCCESS" "Added scripts to $file"
    fi
}

function configure_git_and_ssh_keys() {
    local name=""
    local email=""

    while true; do
        read -r -p "Please Enter your name: " name
        if [[ -z "$name" ]]; then
            log_message "ERROR" "Invalid input. Please enter a non-empty name."
        else
            log_message "INFO" "Your submitted name: $name"
            break
        fi
    done

    while true; do
        read -r -p "Please Enter your Email: " email
        if [[ $email =~ ^[a-zA-Z0-9._-]+@[a-zA-Z0-9._-]+\.[a-zA-Z0-9_-]+$ ]]; then
            log_message "INFO" "Your submitted email: $email"
            break
        else
            log_message "ERROR" "Invalid input. Please enter a valid email."
        fi
    done

    log_message "INFO" "Starting git and SSH configuration"
    configure_git "$name" "$email"
    generate_ssh_key "$email"
}

function clone_obsidian_repo() {
    local git_url=""

    while true; do
        read -r -p "Please Enter your git url: " git_url
        if [[ -z "$git_url" ]]; then
            log_message "ERROR" "Invalid input. Please enter a non-empty git url."
        else
            log_message "INFO" "Your submitted git url: $git_url"
            break
        fi
    done

    base_name=$(basename "$git_url")
    folder_name=${base_name%.*}
    clone_repo "$folder_name" "$git_url"
}

function optimize_repo_for_mobile() {
    local folders=()
    local i=1

    log_message "INFO" "Scanning for git repositories"

    for dir in "$HOME_PATH"/*; do
        if [ -d "$dir" ]; then
            if git -C "$dir" status &> /dev/null; then
                folder_name=$(basename "$dir")
                folders+=("$folder_name")
                log_message "OUTPUT" "$i) $folder_name"
                ((i++))
            fi
        fi
    done

    log_message "INFO" "Select a folder to optimize:"
    read -r choice

    folder="${folders[$choice-1]}"
    log_message "INFO" "Selected folder: $folder"

    if [ -d "$DOWNLOAD_FOLDER/$folder" ]; then
        if git -C "$HOME_PATH/$folder" status &> /dev/null; then
            add_gitignore_entries "$folder"
            add_gitattributes_entry "$folder"
            remove_files_from_git "$folder"
            log_message "SUCCESS" "Repository optimization completed"
        else
            log_message "ERROR" "The $folder folder is not a Git repository"
        fi
    else
        log_message "ERROR" "Folder $DOWNLOAD_FOLDER/$folder doesn't exist. You should clone the repo again."
    fi
}

function create_alias_and_git_scripts() {
    execute_and_log "touch \"$HOME_PATH/.bashrc\"" "Creating .bashrc"
    execute_and_log "touch \"$HOME_PATH/.obsidian\"" "Creating .obsidian"
    execute_and_log "chmod +x \"$HOME_PATH/.obsidian\"" "Making .obsidian executable"
    execute_and_log "touch \"$HOME_PATH/.profile\"" "Creating .profile"

    write_to_file_if_not_exists "$OBSIDIAN_SCRIPT" "$HOME_PATH/.obsidian"
    write_to_file_if_not_exists "source $HOME_PATH/.obsidian" "$HOME_PATH/.profile"
    write_to_file_if_not_exists "source $HOME_PATH/.profile" "$HOME_PATH/.bashrc"

    local folders=()
    local i=1
    for dir in "$HOME_PATH"/*; do
        if [ -d "$dir" ]; then
            if git -C "$dir" status &> /dev/null
            then
                folder_name=$(basename "$dir")
                folders+=("$folder_name")
                echo "$i) $folder_name"
                ((i++))
            fi
        fi
    done
    echo "Now which repository do you want to create scripts for?"
    echo "Select a folder:"
    read -r choice
    folder="${folders[$choice-1]}"
    echo "You selected $folder"
    echo "What do you want your alias to be?"
    read -r alias
    echo "alias $alias='sync_obsidian $HOME_PATH/$folder'" > "$HOME_PATH/.$folder"
    write_to_file_if_not_exists "source $HOME_PATH/.$folder"  "$HOME_PATH/.profile"
    echo "alias $alias created in .$folder"
    echo "You should exit the program for changes to take effect."
}
# shellcheck disable=SC2016

# Modified sync_obsidian function with command output logging
OBSIDIAN_SCRIPT='
function sync_obsidian()
{
    set -euo pipefail
    local log_file="$HOME/logs/$(date +%Y-%m-%d).log"

    # Colors for terminal output
    local RED="\033[0;31m"
    local GREEN="\033[0;32m"
    local BLUE="\033[0;34m"
    local YELLOW="\033[1;33m"
    local NC="\033[0m"

    function log_sync() {
        local level="$1"
        local message="$2"
        local timestamp=$(date "+%Y-%m-%d %H:%M:%S")

        # Write to log file
        echo "[$timestamp] [$level] $message" >> "$log_file"

        # Echo to user with colors
        case "$level" in
            "ERROR")
                echo -e "${RED}ERROR: $message${NC}"
                ;;
            "SUCCESS")
                echo -e "${GREEN}SUCCESS: $message${NC}"
                ;;
            "INFO")
                echo -e "${BLUE}INFO: $message${NC}"
                ;;
            "OUTPUT")
                echo -e "${YELLOW}$message${NC}"
                ;;
        esac
    }

    function execute_sync() {
        local command="$1"
        local description="$2"
        local timestamp=$(date "+%Y-%m-%d %H:%M:%S")

        echo "[$timestamp] [COMMAND] $command" >> "$log_file"
        echo "[$timestamp] [OUTPUT-START]" >> "$log_file"

        # Execute command and stream output in real-time
        local exit_file=$(mktemp)

        (eval "$command" 2>&1 || echo $? > "$exit_file") | while IFS= read -r line; do
            # Write to log file
            echo "$line" >> "$log_file"
            # Show output to user with yellow color
            echo -e "${YELLOW}$line${NC}"
        done

        # Get the exit code
        exit_code=0
        if [ -f "$exit_file" ]; then
            exit_code=$(cat "$exit_file")
            rm "$exit_file"
        fi

        echo "[$timestamp] [OUTPUT-END] (Exit Code: $exit_code)" >> "$log_file"

        return $exit_code
    }

    if [ -z "${1:-}" ]; then
        log_sync "ERROR" "No directory specified. Usage: sync_obsidian <directory>"
        return 1
    fi

    log_sync "INFO" "Starting Obsidian sync for directory: $1"
    if ! execute_sync "cd \"$1\"" "Changing to repository directory"; then
        log_sync "ERROR" "Failed to change directory to $1"
        return 1
    fi

    log_sync "INFO" "Adding changes..."
    execute_sync "git add ." "Adding changes to git"

    if execute_sync "git commit -m \"Android Commit\"" "Committing changes"; then
        log_sync "SUCCESS" "Changes committed successfully"
    else
        log_sync "INFO" "No changes to commit"
    fi

    log_sync "INFO" "Fetching remote changes..."
    if ! execute_sync "git fetch" "Fetching changes"; then
        log_sync "ERROR" "Failed to fetch remote changes"
        return 1
    fi

    log_sync "INFO" "Attempting to merge changes..."
    if ! execute_sync "git merge --no-edit" "Merging changes"; then
        log_sync "ERROR" "Merge failed. Here are the details:"
        execute_sync "git status" "Checking git status"
        return 1
    fi

    log_sync "INFO" "Adding merge results..."
    execute_sync "git add ." "Adding merged changes"

    if execute_sync "git commit -m \"automerge android\"" "Committing merge"; then
        log_sync "SUCCESS" "Merge changes committed"
    else
        log_sync "INFO" "No merge changes to commit"
    fi

    log_sync "INFO" "Pushing changes..."
    if ! execute_sync "git push" "Pushing changes"; then
        log_sync "ERROR" "Push failed. Here are the details:"
        execute_sync "git status" "Checking git status"
        return 1
    fi

    log_sync "SUCCESS" "Sync completed successfully for $1"
}
'


# Main menu loop
while true; do
PS3='Please enter your choice: '

options=(
    "Install Required Dependencies"
    "Give Access to Storage"
    "Configure Git and Create SSH Key"
    "Clone Obsidian Git Repo in Termux"
    "Optimize repository for multi-device use"
    "Create Scripts and git commit scripts"
    "Quit"
)

select opt in "${options[@]}"
do
    case $opt in
        "${options[0]}")
            echo "Installing Required packages"
            install_required_deps
            break
            ;;
        "${options[1]}")
            echo "Getting Access for Storage"
            termux-setup-storage
            break
            ;;
        "${options[2]}")
            echo "Configuring Git and SSH Key"
            configure_git_and_ssh_keys
            break
            ;;
        "${options[3]}")
            echo "Cloning Obsidian Git Repo"
            clone_obsidian_repo
            break
            ;;
        "${options[4]}")
            echo "Optimize repository for obsidian mobile"
            optimize_repo_for_mobile
            break
            ;;
        "${options[5]}")
            echo "Creating Alias and git commit scripts"
            create_alias_and_git_scripts
            break
            ;;
        "${options[6]}")
            exit 0
            ;;
        *) echo "Invalid option" ;;
    esac
done

echo "-------------------------------------"
done
