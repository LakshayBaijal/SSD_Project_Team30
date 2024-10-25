#!/bin/bash

# ==========================================
# Log Analyzer Script
# ==========================================
# This script presents a menu to the user to choose
# between different log analysis options, collects
# the required input, and executes the corresponding
# analysis script with the provided parameters.
# ==========================================


display_header() {
    echo -e "\e[1;34m==================================================\e[0m"
    echo -e "\e[1;32m                Log Analyzer\e[0m"
    echo -e "\e[1;34m==================================================\e[0m"
    echo
}

display_menu() {
    echo -e "Analyser> \e[1;33mPlease choose an option:\e[0m"
    echo -e "Analyser> \e[1;36m1. Analyze Memory\e[0m"
    echo -e "Analyser> \e[1;36m2. Processes\e[0m"
    echo -e "Analyser> \e[1;36m3. Package Manager\e[0m"
    echo -e "Analyser> \e[1;36m4. Authenticate\e[0m"
    echo -e "Analyser> \e[1;36m5. Quit\e[0m"  
    echo
}


get_user_choice() {
    local choice
    while true; do
        read -p $'Analyser> \e[1;35mEnter your choice [1-5]: \e[0m' choice  
        case $choice in
            1|2|3|4|5) 
                echo "$choice"
                return
                ;;
            *)
                echo -e "Analyser> \e[1;31mInvalid choice. Please enter a number between 1 and 5.\e[0m"
                ;;
        esac
    done
}

# Function to read and validate the date input
get_date() {
    local date_input
    while true; do
        read -p $'Analyser> \e[1;35mEnter the date (YYYY-MM-DD): \e[0m' date_input
        if [[ "$date_input" =~ ^[0-9]{4}-[0-9]{2}-[0-9]{2}$ ]]; then
            echo "$date_input"
            return
        else
            echo -e "Analyser> \e[1;31mInvalid date format. Please use YYYY-MM-DD.\e[0m"
        fi
    done
}

# Function to read and validate the time input
get_time() {
    local time_input
    while true; do
              read -p $'Analyser> \e[1;35m'"$1"$'\e[0m' time_input
        if [[ "$time_input" =~ ^([01][0-9]|2[0-3]):([0-5][0-9]):([0-5][0-9])$ ]]; then
            echo "$time_input"
            return
        else
            echo -e "Analyser> \e[1;31mInvalid time format. Please use HH:MM:SS.\e[0m"
        fi
    done
}


clear
export PS1="Analyzer>"
display_header

while true; do
   



 
    display_menu

    choice=$(get_user_choice)

   
    if [[ "$choice" -eq 5 ]]; then
        echo -e "Analyser> \e[1;32mExiting the Analyser.\e[0m"
        break
    fi

    selected_option="$choice"

  
    date=$(get_date)

    start_time=$(get_time "Enter the start time (HH:MM:SS): ")
    end_time=$(get_time "Enter the end time (HH:MM:SS): ")

    echo
    echo -e "Analyser> \e[1;32mYou have selected option $selected_option with the following parameters:\e[0m"
    echo -e "Analyser> \e[1;34mDate: $date\e[0m"
    echo -e "Analyser> \e[1;34mStart Time: $start_time\e[0m"
    echo -e "Analyser> \e[1;34mEnd Time: $end_time\e[0m"
    echo

    case $selected_option in
        1)
            echo "Calling ./test_mem.sh"
            bash ./test_mem.sh "$date" "$start_time" "$end_time"
            ;;
        2)
            echo "Calling ./test_proc.sh"
            bash ./test_proc.sh "$date" "$start_time" "$end_time"
     
            ;;
        3)
            if [[ -x test_dpkg.sh ]]; then
                bash ./test_dpkg.sh "$date" "$start_time" "$end_time"
            else
                echo "Error: ./test_dpkg.sh not found or not executable."
            fi
            ;;
        4)
            if [[ -x ./test_auth.sh ]]; then
                bash ./test_auth.sh "$date" "$start_time" "$end_time"
            else
                echo "Error: ./test_auth.sh not found or not executable."
            fi
            ;;
        *)
            echo "Invalid option selected. Exiting."
            exit 1
            ;;
    esac

    echo -e "\nAnalyser> \e[1;33mPress Enter to continue...\e[0m"
    read 
done
