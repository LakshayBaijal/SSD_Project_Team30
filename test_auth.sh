#!/bin/bash

LOG_FILE="/var/log/auth.log"  # Specify the log file you want to parse
INPUT_DATE=$1  # Replace with dynamic date if needed
START_TIME=$2
END_TIME=$3



declare -A AUTH_FAILUER_DATE
declare -A SUDO_PRIVILEGES_DATA
declare -A SESSION_APPLICATIONS
declare -A OTHER_EVENTS

categorize_message() {
    local message="$1"
    local log_date="$2"
    local timestamp="$3"
    local app_name="$4"



    if [[ "$message" =~ "authentication failure" ]]; then
        # Authentication Failure
        logname=$(echo "$message" | grep -oP "logname=\K[^ ]+")
        user=$(echo "$message" | grep -oP "user=\K[^ ]+")
        AUTH_FAILUER_DATE+=("$log_date $timestamp\t\t$logname\t\t$user")
    elif [[ "$message" =~ "COMMAND=" ]]; then
        # Sudo Privileges
        pwd=$(echo "$message" | grep -oP "PWD=\K[^ ]+")
        command=$(echo "$message" | grep -oP "COMMAND=\K[^ ]+")
        sudo_user=$(echo "$message" | grep -oP "USER=\K[^ ]+")
        SUDO_PRIVILEGES_DATA+=("$log_date $timestamp\t\t$sudo_user\t$pwd\t$command")
    elif [[ "$message" =~ "session opened" ]]; then
        # Session Opened - Increment count for the application
        if [[ -n "$app_name" ]]; then
        
            if [[ -v SESSION_APPLICATIONS["$app_name"] ]]; then

                SESSION_APPLICATIONS["$app_name"]=$((SESSION_APPLICATIONS["$app_name"] + 1))
            else
                SESSION_APPLICATIONS["$app_name"]=1
            fi
        fi
    else 
      OTHER_EVENTS["$app_name"]=$((OTHER_EVENTS["$app_name"] + 1))
     
    fi
}


display_results() {
    # Display authentication failures
    echo -e "\e[31mAuthentication Failures\e[0m"
     echo "----------------------------------------------------------------------" 
    printf "%-25s %-25s %-25s\n" "Timestamp" "Logname" "User"
    echo "----------------------------------------------------------------------"  # Adjusted length to match the header width
    for record in "${AUTH_FAILUER_DATE[@]}"; do
        echo -e "$record"
    done
    echo

    # Display sudo privileges
    echo -e "\e[31mSudo Privileges\e[0m"
     echo "-------------------------------------------------------------------------------------------"
    printf "%-25s %-25s %-25s %-25s\n" "Timestamp" "Sudo User" "PWD" "Command"
    echo "-------------------------------------------------------------------------------------------"  # Adjusted length to match header width
    for record in "${SUDO_PRIVILEGES_DATA[@]}"; do
        echo -e "$record"
    done
    echo

    # Display session report
    echo -e "\e[31mSession Report\e[0m"
     echo "----------------------------------------------------------------------" 
    printf "%-25s %-25s\n" "Application Name" "Number of Sessions"
    echo "----------------------------------------------------------------------"  # Adjusted length to match the header width

    for app in "${!SESSION_APPLICATIONS[@]}"; do
        count=${SESSION_APPLICATIONS[$app]}
        printf "%-25s %-25s\n" "$app" "$count"
    done
}


generate_graph() {
    echo -e "\n\e[34mGraphical Representation:\e[0m"

    # Total counts
    total_failed_logins=0
    for user in "${!AUTH_FAILURE_DATA[@]}"; do
        count=${AUTH_FAILURE_DATA[$user]}
        total_failed_logins=$((total_failed_logins + count))
    done

    total_successful_logins=0
    for user in "${!SUDO_PRIVILEGES_DATA[@]}"; do
        count=${SUDO_PRIVILEGES_DATA[$user]}
        total_successful_logins=$((total_successful_logins + count))
    done

    total_session_opens=0
    for app in "${!SESSION_APPLICATIONS[@]}"; do
        count=${SESSION_APPLICATIONS[$app]}
        total_session_opens=$((total_session_opens + count))
    done

    total_other_events=0
    for event in "${!OTHER_EVENTS[@]}"; do
        count=${OTHER_EVENTS[$event]}
        total_other_events=$((total_other_events + count))
    done

    # Calculate total of all events
    total_events=$((total_failed_logins + total_successful_logins + total_session_opens + total_other_events))

    # Find the maximum value among the counts for scaling
    max_value=$total_failed_logins
    if [ "$total_successful_logins" -gt "$max_value" ]; then
        max_value=$total_successful_logins
    fi
    if [ "$total_session_opens" -gt "$max_value" ]; then
        max_value=$total_session_opens
    fi
    if [ "$total_other_events" -gt "$max_value" ]; then
        max_value=$total_other_events
    fi

    if [ "$max_value" -eq 0 ]; then
        max_value=1  # Prevent division by zero
    fi

    # Normalize counts for graph scaling
    normalized_failed_logins=$(( total_failed_logins * 50 / max_value ))
    normalized_successful_logins=$(( total_successful_logins * 50 / max_value ))
    normalized_session_opens=$(( total_session_opens * 50 / max_value ))
    normalized_other_events=$(( total_other_events * 50 / max_value ))

    # Ensure at least one block for non-zero counts
    if [ "$total_failed_logins" -gt 0 ] && [ "$normalized_failed_logins" -eq 0 ]; then
        normalized_failed_logins=1
    fi
    if [ "$total_successful_logins" -gt 0 ] && [ "$normalized_successful_logins" -eq 0 ]; then
        normalized_successful_logins=1
    fi
    if [ "$total_session_opens" -gt 0 ] && [ "$normalized_session_opens" -eq 0 ]; then
        normalized_session_opens=1
    fi
    if [ "$total_other_events" -gt 0 ] && [ "$normalized_other_events" -eq 0 ]; then
        normalized_other_events=1
    fi

    # Print the graph using specified colors
    # Total Failed Logins (Severe Errors)
    printf "Failed Logins:  "
    for ((i=0; i<normalized_failed_logins; i++)); do
        printf "\e[31m▅\e[0m"  # Red
    done
    printf " $total_failed_logins\n"

    # Total Successful Logins (Success)
    printf "Successful Logins:   "
    for ((i=0; i<normalized_successful_logins; i++)); do
        printf "\e[32m▅\e[0m"  
    done
    printf " $total_successful_logins\n"

    # Total Session Openings (Warnings)
    printf "Session Openings:    "
    for ((i=0; i<normalized_session_opens; i++)); do
        printf "\e[91m▅\e[0m" 
    done
    printf " $total_session_opens\n"

    # Total Other Events
    printf "Other Events:        "
    for ((i=0; i<normalized_other_events; i++)); do
         printf "\e[38;5;214m▅\e[0m"
    done
    printf " $total_other_events\n"

    # Print the total events count
    echo -e "\n\e[35mTotal Events:        $total_events\e[0m"  # Magenta
}


parse_log() {
    local log_file="$LOG_FILE"
    local date_format
    local sample_line

    # Read the first line to determine its date format
    read -r sample_line < "$log_file"

    # Determine the date format of the sample line
    if [[ $sample_line =~ ^[A-Za-z]{3}[[:space:]]+[0-9]{1,2} ]]; then
        date_format=2  
    elif [[ $sample_line =~ ^[0-9]{4}-[0-9]{2}-[0-9]{2} ]]; then
        date_format=1  
    else
        echo "Error: Unsupported date format in log file."
        return 1
    fi

    # Parse the log file
    while IFS= read -r line; do
        local app_name=""
        local message=""
        local log_date=""
        local timestamp=""
       
        if [[ $date_format -eq 1 ]]; then  # yyyy-mm-dd format
            if [[ $line =~ ([0-9]{4})-([0-9]{2})-([0-9]{2}) ]]; then
                log_date="${BASH_REMATCH[0]}"

                if [[ "$log_date" == "$INPUT_DATE" ]]; then
                    timestamp=$(echo "$line" | awk -F'T' '{print $2}' | cut -d '.' -f 1)

                    # Check if timestamp is within the specified range
                    if [[ "$timestamp" > "$START_TIME" || "$timestamp" == "$START_TIME" ]] && [[ "$timestamp" < "$END_TIME" || "$timestamp" == "$END_TIME" ]]; then
                       app_name=$(echo "$line" | awk '{print $3}' | cut -d'[' -f1 | sed 's/:$//')  # Extract app name without PID
                        message=$(echo "$line" | awk -F ']: ' '{gsub(/^ +| +$/, "", $2); print $2}')  # Extract message and trim spaces
                        #echo "Extracted message: '$message'"  # Debugging statement
                    
                       
                    fi
                fi
            fi
        elif [[ $date_format -eq 2 ]]; then  # mmm dd format
            if [[ $line =~ ^[A-Za-z]{3}[[:space:]]+[0-9]{1,2} ]]; then
                log_date="${BASH_REMATCH[0]}"
                date_mmm_dd=$(date -d "$INPUT_DATE" +"%b %d")  # Convert INPUT_DATE to mmm dd format

                if [[ "$log_date" == "$date_mmm_dd" ]]; then
                    app_name=$(echo "$line" | awk '{print $5}' | cut -d '[' -f 1)
                    message=$(echo "$line" | cut -d ':' -f 3- | sed -e "s/^ *//" -e "s/ *$//")  # Trim whitespaces

                    # Clean up app name
                    app_name="${app_name%:}"        # Remove trailing colon if exists
                    app_name="${app_name%[]}"
                    app_name="${app_name%]}"       # Remove trailing bracket if exists
                   # echo "Extracted message: '$message'"  # Debugging statement
                fi
            fi
        fi

        # Check if message is not empty
        if [[ -n "$message" ]]; then
            # Categorize the message
            local category
          
            categorize_message "$message" "$log_date" "$timestamp" "$app_name"

        

        fi
        
    done < "$LOG_FILE"
}



main() {
    if [[ -f $LOG_FILE ]]; then
        parse_log "$LOG_FILE"
       # print_summary

        printf "\n"
        display_results
        printf "\n"
        generate_graph

      

    else
        printf "Error: Log file %s not found\n" "$LOG_FILE" >&2
        return 1
    fi
}

main "$@"