#!/bin/bash
echo "Script Version 0.4.1.4"
echo "This script is used to facilitate configuration of git for obsidian. "

HOME_PATH="/data/data/com.termux/files/home"
DOWNLOAD_FOLDER="$HOME_PATH/storage/shared/Download"


# Define functions for each menu option
function install_required_deps()
{
    apt update
    apt upgrade -y
    pkg install openssh -y
    pkg install git -y
}

function access_storage()
{
    termux-setup-storage
}

function configure_git() {

    name="$1"
    email="$2"

    git config --global user.name "$name"
    git config --global user.email "$email"

    git config --global credential.helper store
    git config --global pull.rebase false
    git config --global --add safe.directory '*'
    git config --global core.protectNTFS false
    git config --global core.longpaths true
}

function generate_ssh_key() {
    email="$1"
    # Check if key already exists
    if [ ! -f $HOME_PATH/.ssh/id_ed25519 ]; then
        # Generate key non-interactively
        ssh-keygen -q -t ed25519 -N "" -f $HOME_PATH/.ssh/id_ed25519 -C "$email"
        echo "Generated new SSH key with email $email"
    else
        echo "SSH key already exists"
    fi
    echo "Here is your SSH public key. You can paste it inside Github"
    echo "------------"
    cat $HOME_PATH/.ssh/id_ed25519.pub
    echo "------------"
    eval "$(ssh-agent -s)"
    ssh-add
}

function clone_repo() {
    folder="$1"
    git_url="$2"
    echo "Git Folder: $HOME_PATH/$folder"
    echo "Obsidian Folder: $DOWNLOAD_FOLDER/$folder"
    echo "Git Url: $git_url"

    cd "$HOME_PATH/" || { echo "Failure while changing directory into $HOME_PATH"; exit 1; }
    mkdir -p "$HOME_PATH/$folder"

    git --git-dir "$HOME_PATH/$folder" --work-tree "$DOWNLOAD_FOLDER/$folder" clone "$git_url"
    cd "$HOME_PATH/$folder" || { echo "Failure while changing directory into $HOME_PATH/$folder"; exit 1; }
    git worktree add --checkout "$DOWNLOAD_FOLDER/$folder" --force
}

# add gitignore file
function add_gitignore_entries() {
    folder_name="$1"
    cd "$DOWNLOAD_FOLDER/$folder_name" || { echo "Failure while changing directory into $DOWNLOAD_FOLDER/$folder_name"; exit 1; }
    GITIGNORE=".gitignore"

    ENTRIES=".trash/
    .obsidian/workspace
    .obsidian/workspace.json
    .obsidian/workspace-mobile.json"

    if [ ! -f "$GITIGNORE" ]; then
        touch "$GITIGNORE"
    fi

    for entry in $ENTRIES; do
        if ! grep -q -Fx "$entry" "$GITIGNORE"; then
            echo "$entry" >> "$GITIGNORE"
        fi
    done

}

function add_gitattributes_entry() {
    folder_name="$1"
    cd "$DOWNLOAD_FOLDER/$folder_name" || { echo "Failure while changing directory into $DOWNLOAD_FOLDER/$folder_name"; exit 1; }
    GITATTRIBUTES=".gitattributes"
    ENTRY="*.md merge=union"

    if [ ! -f "$GITATTRIBUTES" ]; then
        touch "$GITATTRIBUTES"
    fi

    if ! grep -q -F "$ENTRY" "$GITATTRIBUTES"; then
        echo "$ENTRY" >> "$GITATTRIBUTES"
    fi

}

function remove_files_from_git()
{
    folder_name="$1"
    cd "$DOWNLOAD_FOLDER/$folder_name" || { echo "Failure while changing directory into $DOWNLOAD_FOLDER/$folder_name"; exit 1; }

    FILES=".obsidian/workspace
    .obsidian/workspace.json
    .obsidian/workspace-mobile.json"

    for file in $FILES; do
        if [ -f "$file" ]; then
            cd "$HOME_PATH/$folder_name" || { echo "Failure while changing directory into $HOME_PATH/$folder_name"; exit 1; }
            git rm --cached "$file"
        fi
    done
    cd "$HOME_PATH/$folder_name" || { echo "Failure while changing directory into $HOME_PATH/$folder_name"; exit 1; }
    if git status | grep "new file" ; then
        git commit -am "Remove ignored files"
    fi

}

function write_to_file_if_not_exists()
{
    content="$1"
    file="$2"
    if [ ! -f "$file" ]; then
        touch "$file"
        echo "created file $file"
    fi
    if ! grep -qxF "$content" "$file"; then
        echo "$content" >> "$file"
        echo "added scripts to $file"
    fi
}

function configure_git_and_ssh_keys()
{
    while true; do
        read -r -p "Please Enter your name: " name
        if [[ -z "$name" ]]; then
            echo "Invalid input. Please enter a non-empty name."
        else
            echo "Your submitted name: $name"
            break
        fi
    done
    while true; do
        read -r -p "Please Enter your Email: " email
        if [[ $email =~ ^[a-zA-Z0-9._-]+@[a-zA-Z0-9._-]+\.[a-zA-Z0-9_-]+$ ]]; then
            echo "Your submitted email: $email"
            break
        else
            echo "Invalid input. Please enter a valid email."
        fi
    done
    echo "-------------------------------------"
    configure_git "$name" "$email"
    generate_ssh_key "$email"
}
function clone_obsidian_repo()
{
    while true; do
        echo "Please Enter your git url: "
        read -r git_url
        if [[ -z "$git_url" ]]; then
            echo "Invalid input. Please enter a non-empty git url."
        else
            echo "Your submitted git url: $git_url"
            break
        fi
    done
    base_name=$(basename "$git_url")
    folder_name=${base_name%.*}
    clone_repo "$folder_name" "$git_url"
}
function optimize_repo_for_mobile()
{
    folders=()
    i=1
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
    echo "Now which repository do you want to optimize?"
    echo "Select a folder:"
    read -r choice
    folder="${folders[$choice-1]}"
    echo "You selected $folder"
    if [ -d "$DOWNLOAD_FOLDER/$folder" ]; then
        if git -C "$HOME_PATH/$folder" status &> /dev/null
        then
            add_gitignore_entries "$folder"
            add_gitattributes_entry "$folder"
            remove_files_from_git "$folder"
        else
            echo "The $folder folder is not a Git repository"
        fi
    else
        echo "Folder $DOWNLOAD_FOLDER/$folder doesn't exist. You should clone the repo again."
    fi
}
function create_alias_and_git_scripts()
{
    touch "$HOME_PATH/.bashrc"
    touch "$HOME_PATH/.obsidian"
    chmod +x "$HOME_PATH/.obsidian"
    touch "$HOME_PATH/.profile"
    # append this to file only if it is not already there
    write_to_file_if_not_exists "$OBSIDIAN_SCRIPT" "$HOME_PATH/.obsidian"
    write_to_file_if_not_exists "source $HOME_PATH/.obsidian" "$HOME_PATH/.profile"
    write_to_file_if_not_exists "source $HOME_PATH/.profile" "$HOME_PATH/.bashrc"


    folders=()
    i=1
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

OBSIDIAN_SCRIPT='
function sync_obsidian()
{
    cd "$1" || { echo "Failure while changing directory into $1"; exit 1; }
    git add .
    git commit -m "Android Commit"
    git fetch
    git merge --no-edit
    git add .
    git commit -m "automerge android"
    git push
    echo "Sync is finished"
    sleep 2
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