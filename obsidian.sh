#!/bin/bash

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
  if [ ! -f ~/.ssh/id_ed25519 ]; then
    # Generate key non-interactively
    ssh-keygen -q -t ed25519 -N "" -f ~/.ssh/id_ed25519 -C "$email" 
    echo "Generated new SSH key with email $email"
  else   
    echo "SSH key already exists"
  fi
}


# Main menu loop
while true; do
    PS3='Please enter your choice: '

    options=(
        "Install Required Dependencies"
        "Give Access to Storage" 
        "Configure Git and Create SSH Key"
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
                    read -p "Please Enter your Email: " mail
                    if [[ $mail =~ ^[A-Za-z0-9._%+-]+@[A-Za-z0-9.-]+\.[A-Za-z]{2,4}$ ]]; then
                        echo "Invalid input. Please enter a valid email."
                    else
                        echo "Your submitted email: $mail"
                        break
                    fi
                done
                echo "$name"
                #configure_git
                #generate_ssh_key
                break
                ;;
            "${options[3]}")
                exit 0
                ;;
            *) echo "Invalid option";;
        esac
    done

    echo "-------------------------------------"
done