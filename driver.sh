#!/bin/bash
display_header() {
    echo -e "\e[1;34m==================================================\e[0m"
    echo -e "\e[1;32m                Log Analyzer\e[0m"
    echo -e "\e[1;34m==================================================\e[0m"
    echo
}
display_menu() {
    echo -e "Analyser> \e[1;33mPlease choose an option:\e[0m"
    echo
    echo -e "Analyser> \e[1;36m1. Analyze Memory\e[0m"
    echo -e "Analyser> \e[1;36m2. Processes\e[0m"
    echo -e "Analyser> \e[1;36m3. Package Manager\e[0m"
    echo -e "Analyser> \e[1;36m4. Authenticate\e[0m"
    echo -e "Analyser> \e[1;36m5. Quick System status\e[0m"
    echo -e "Analyser> \e[1;36m6. Quit\e[0m" 
    echo
    echo
}

get_user_choice() {
    local choice
    while true; do
        read -p $'Analyser> \e[1;35mEnter your choice [1-6]: \e[0m' choice
        case $choice in
            1|2|3|4|5|6) 
                echo "$choice"
                return $choice
                ;;
            *)
                echo -e "Analyser> \e[1;31mInvalid choice. Please enter a number between 1 and 5.\e[0m"
                ;;
        esac
    done
}


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
#################################################################################################################################################

while true; do
    clear
    display_header
    
    echo -e "\e[1;33mSelect Log Analysis Type:\e[0m" 
    echo
    echo -e "\e[1;36m1) Ubuntu System Log Analysis\e[0m" 
    echo -e "\e[1;36m2) Custom Log File Analysis\e[0m" 
    echo -e "\e[1;36m3) Exit\e[0m" 
    echo
    
    read -p $'\e[1;35mEnter your choice [1-3]: \e[0m' main_choice 
    echo

    case $main_choice in
        1)
            
            

            display_menu
            
            choice=$(get_user_choice)
            
            if [[ "$choice" -eq 6 ]]; then
                echo -e "Analyser> \e[1;32mExiting the Analyser.\e[0m"
                break
            fi
            selected_option="$choice"
            

            echo
            echo -e "Analyser> \e[1;33mWould you like to specify a custom log file, or use the default log file?\e[0m" 
            echo
            echo -e "Analyser> \e[1;36m1) Use a custom log file\e[0m" 
            echo -e "Analyser> \e[1;36m2) Use a default log file\e[0m" 
            echo
            read -p $'Analyser> \e[1;35mEnter your choice [1-2]: \e[0m' ch
            echo
            logFilePath=""

            if [[ "$ch" -eq 1 ]]; then
                read -p "Enter the path to your log file: " logFilePath
                if [ -f "$logFilePath" ]; then 
                    echo "File exists ✅" 
                    echo "Log file path: $logFilePath"
                else 
                    echo "File does not exist"
                    echo -e "\nAnalyser> \e[1;33mPress Enter to continue...\e[0m"
                    read
                    continue;
                fi
            else
            
                logFilePath="nofile"
            fi

            echo

            

            date=$(get_date)
            start_time=$(get_time "Enter the start time (HH:MM:SS): ")
            end_time=$(get_time "Enter the end time (HH:MM:SS): ")
            echo
            clear
            display_header
            echo

            echo -e "Analyser> \e[1;32mYou have selected option $selected_option with the following parameters:\e[0m"
            echo -e "Analyser> \e[1;34mDate: $date\e[0m"
            echo -e "Analyser> \e[1;34mStart Time: $start_time\e[0m"
            echo -e "Analyser> \e[1;34mEnd Time: $end_time\e[0m"
            echo
            
            case $selected_option in
                1) bash ./test_mem.sh "$date" "$start_time" "$end_time" "$logFilePath" ;;
                2) bash ./test_proc.sh "$date" "$start_time" "$end_time" "$logFilePath" ;;
                3) if [[ -e test_dpkg.sh ]]; then
                    bash ./test_dpkg.sh "$date" "$start_time" "$end_time" "$logFilePath"
                    else
                        echo "Error: ./test_dpkg.sh not found or not executable."
                    fi ;;
                4) if [[ -e ./test_auth.sh ]]; then
                        bash ./test_auth.sh "$date" "$start_time" "$end_time" "$logFilePath"
                    else
                        echo "Error: ./test_auth.sh not found or not executable."
                    fi ;;
                5) bash ./sys_stat.sh "$date" "$start_time" "$end_time" ;;
                *) echo "Invalid option selected. Exiting." ; exit 1 ;;
            esac
            ;;

        2)
            echo -e "\e[1;34mChoose Operating System for Log File Analysis:\e[0m"
            echo -e "\e[1;33m1) Windows\e[0m"
            echo -e "\e[1;33m2) MACOS\e[0m"
            echo -e "\e[1;33m3) Solaris\e[0m"
            echo -e "\e[1;33m4) Exit\e[0m"
            echo
            read -p $'\e[1;35mEnter your choice [1-3]: \e[0m' os_choice
            echo

            case $os_choice in
                1)
                    echo -e "\e[1;34mYou selected Windows.\e[0m"
                    echo -e "\e[1;33m1) CBS Logs\e[0m"
                    echo -e "\e[1;33m2) System Logs\e[0m"
                    echo -e "\e[1;33m3) Security Logs\e[0m"
                    echo
                    read -p $'\e[1;35mSelect the type of Windows log file [1-3]: \e[0m' windows_log_choice
                    echo
                    
                    case $windows_log_choice in
                        1) os_script="test_windows_CBS.sh" ;;
                        2) os_script="test_windows_sys.sh" ;;
                        3) os_script="test_windows_sec.sh" ;;
                        *) echo "Invalid choice for Windows log type. Exiting." ; exit 1 ;;
                    esac
                    ;;
                2) os_script="macos.sh" ;;
                3) os_script="solarisOS.sh" ;;
                4) echo "Exiting from analyzer." ; exit 1 ;;
                *) echo "Invalid OS choice. Exiting." ; exit 1 ;;
            esac

            echo
            read -p "Enter the log file path: " logFilePath
            if [ -f "$logFilePath" ]; then 
                echo "File exists ✅"
                echo
            else 
                echo "File does not exist"
                echo -e "\nAnalyser> \e[1;33mPress Enter to continue...\e[0m"
                read
                exit 1
            fi

            date=$(get_date)
            start_time=$(get_time "Enter the start time (HH:MM:SS): ")
            end_time=$(get_time "Enter the end time (HH:MM:SS): ")

            echo
            clear
            display_header
            echo

            echo -e "Analyser> \e[1;32mYou have selected $os_script with the following parameters:\e[0m"
            echo -e "Analyser> \e[1;34mLog File Path: $logFilePath\e[0m"
            echo -e "Analyser> \e[1;34mDate: $date\e[0m"
            echo -e "Analyser> \e[1;34mStart Time: $start_time\e[0m"
            echo -e "Analyser> \e[1;34mEnd Time: $end_time\e[0m"
            echo

            if [[ -e ./$os_script ]]; then
                sudo bash ./$os_script "$date" "$start_time" "$end_time" "$logFilePath"
            else
                echo "Error: ./$os_script not found or not executable."
            fi

            ;;

        3)
            echo -e "Analyser> \e[1;32mExiting the Analyser.\e[0m"
            clear
            break
            ;;
        *)
            echo "Invalid option. Please enter 1 or 2 or 3."
            ;;
    esac
    
    echo -e "\nAnalyser> \e[1;33mPress Enter to continue...\e[0m"
    read 
done