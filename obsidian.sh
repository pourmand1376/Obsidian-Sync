#!/bin/bash

# Define functions for each menu option
function list_files {
    ls
}

function display_system_info {
    uname -a
}

function list_processes {
    ps -ef
}

# Main menu loop
while true; do
    PS3='Please enter your choice: '

    options=(
        "List files in current directory"
        "Display system info" 
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