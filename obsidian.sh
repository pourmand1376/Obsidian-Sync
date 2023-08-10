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

function list_processes {
    ps -ef
}

# Main menu loop
while true; do
    PS3='Please enter your choice: '

    options=(
        "Install Required Dependencies"
        "Give Access to Storage" 
        "List running processes"
        "Quit"
    )

    select opt in "${options[@]}"
    do
        case $opt in
            "${options[0]}")
                list_files
                break
                ;;
            "${options[1]}")
                display_system_info
                break
                ;;
            "${options[2]}")
                list_processes
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