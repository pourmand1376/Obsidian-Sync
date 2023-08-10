#!/bin/bash
echo "Script Version 0.0.8"
echo "This script is used to facilitate configuration of git for obsidian. "

HOME_PATH="/data/data/com.termux/files/home"
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

configure_git() {

  name="$1"
  email="$2"

  git config --global user.name "$name"
  git config --global user.email "$email"

  git config --global credential.helper store
  git config --global pull.rebase false
  git config --global --add safe.directory '*'
  git config --global core.protectNTFS false

}

generate_ssh_key() {
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
  eval $(ssh-agent -s)
  ssh-add
}

clone_repo() {
  folder="$1"
  git_url="$2"
  echo "Git Folder: $folder"
  echo "Obsidian Folder: $HOME_PATH/storage/downloads/$folder"
  echo "Git Url: $git_url"

  cd "$HOME_PATH/"
  mkdir -p "$HOME_PATH/$folder"
  git --git-dir "$HOME_PATH/$folder" --work-tree "$HOME_PATH/storage/downloads/$folder" clone "$git_url" 

}

# add gitignore file
add_gitignore_entries() {
folder_name="$1"
cd "$HOME_PATH/storage/downloads/$folder_name"
  GITIGNORE=".gitignore"

  ENTRIES=".trash/ 
.obsidian/workspace
.obsidian/workspace.json
.obsidian/workspace-mobile.json
.obsidian/app.json"

  if [ ! -f "$GITIGNORE" ]; then
    touch "$GITIGNORE"
  fi

  for entry in $ENTRIES; do
    if ! grep -q -Fx "$entry" "$GITIGNORE"; then
      echo "$entry" >> "$GITIGNORE"
    fi
  done

}

add_gitattributes_entry() {
folder_name="$1"
cd "$HOME_PATH/storage/downloads/$folder_name"
  GITATTRIBUTES=".gitattributes"
  ENTRY="*.md merge=union"

  if [ ! -f "$GITATTRIBUTES" ]; then
    touch "$GITATTRIBUTES"
  fi

  if ! grep -q -F "$ENTRY" "$GITATTRIBUTES"; then
    echo "$ENTRY" >> "$GITATTRIBUTES"
  fi

}

remove_files_from_git()
{
folder_name="$1"
cd "$HOME_PATH/storage/downloads/$folder_name"

FILES=".obsidian/workspace 
.obsidian/workspace.json
.obsidian/workspace-mobile.json
.obsidian/app.json"

for file in $FILES; do
  if [ -f "$file" ]; then
    cd "$HOME_PATH/$folder_name"
    git rm --cached "$file"
  fi 
done
cd "$HOME_PATH/$folder_name"
if git status | grep "new file" ; then
  git commit -am "Remove ignored files"
fi

}


# Main menu loop
while true; do
    PS3='Please enter your choice: '

    options=(
        "Install Required Dependencies"
        "Give Access to Storage" 
        "Configure Git and Create SSH Key"
        "Clone Obsidian Git Repo in Termux"
        "Optimize repository for multi-device use"
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
                while true; do
                    read -p "Please Enter your name: " name
                    if [[ -z "$name" ]]; then
                        echo "Invalid input. Please enter a non-empty name."
                    else
                        echo "Your submitted name: $name"
                        break
                    fi
                done
                while true; do
                    read -p "Please Enter your Email: " email
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
                break
                ;;
            "${options[3]}")
                echo "Cloning Obsidian Git Repo"
                while true; do
                    read -p "Please Enter your git url: " git_url
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
                break
                ;;
            "${options[4]}")
                echo "Optimize repository for obsidian mobile"
                while true; do
                    echo "Please Enter your folder name which you cloned into:"
                    read folder_name
                    if [[ $folder_name =~ ^[a-zA-Z0-9_\-]+$ ]]; then
                        if [ -d "$folder_name" ]; then
                        echo "Folder name submitted: $folder_name"
                        # Try git status on the folder
                        if git -C "$folder_name" status &> /dev/null
                        then
                            echo "The $folder_name folder is a Git repository"
                            break 
                        else
                            echo "The $folder_name folder is not a Git repository"
                        fi
                        else  
                        echo "This folder doesn't exist. You haven't cloned the git repo. To use this option, first clone the git repository into a folder"
                        fi
                    else
                    echo "Invalid input. Please enter a valid folder name."
                    fi
                done
                if [ -d "~/storage/downloads/$folder_name" ]; then
                    add_gitignore_entries "$folder_name"
                    add_gitattributes_entry "$folder_name"
                    remove_files_from_git "$folder_name"
                else
                    echo "Folder ~/storage/downloads/$folder_name doesn't exist. You should clone the repo again."
                fi
                break
                ;;
            "${options[5]}")
                exit 0
                ;;
            *) echo "Invalid option";;
        esac
    done

    echo "-------------------------------------"
done