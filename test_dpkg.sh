#!/bin/bash

LOG_FILE="/var/log/dpkg.log"
INPUT_DATE=$1
START_TIME=$2
END_TIME=$3

declare -A package_actions
declare -A ACTION_COLORS

generate_graph() {
    if [ ${#package_actions[@]} -eq 0 ]; then
        exit 0
    fi

    echo -e "\n\e[34mGraphical Representation of Actions:\e[0m"

    declare -A action_counts
    for action in "${package_actions[@]}"; do
        ((action_counts[$action]++))
    done

    max_value=0
    total_actions=0
    for count in "${action_counts[@]}"; do
        total_actions=$((total_actions + count))
        if [[ "$count" -gt "$max_value" ]]; then
            max_value="$count"
        fi
    done

    if [[ "$max_value" -eq 0 ]]; then
        max_value=1
    fi

    for action in "${!action_counts[@]}"; do
        count="${action_counts[$action]}"
        normalized_count=$(( count * 50 / max_value ))

        color=${ACTION_COLORS["$action"]}
        [ -z "$color" ] && color="\e[37m"

        printf "%-15s: " "$action"
        for ((i=0; i<normalized_count; i++)); do
            printf "${color}▅\e[0m"
        done
        printf " $count\n"
    done

    echo -e "\n\e[34mTotal Package Actions: \e[0m$total_actions"
}



parse_log() {
    local log_file="$LOG_FILE"
    local date_format
    local sample_line

    
    read -r sample_line < "$log_file"

  
    if [[ $sample_line =~ ^[A-Za-z]{3}[[:space:]]+[0-9]{1,2} ]]; then
        date_format=2  # mmm dd format
    elif [[ $sample_line =~ ^[0-9]{4}-[0-9]{2}-[0-9]{2} ]]; then
        date_format=1  # yyyy-mm-dd format
    else
        echo "Error: Unsupported date format in log file."
        return 1
    fi

 
   
    local status=""
    local package_name=""
    local version=""
    local log_date=""
    local timestamp=""

    while IFS= read -r line; do
        if [[ $date_format -eq 1 ]]; then  # yyyy-mm-dd format
            if [[ $line =~ ([0-9]{4})-([0-9]{2})-([0-9]{2}) ]]; then
                log_date="${BASH_REMATCH[0]}"
               

                if [[ "$log_date" == "$INPUT_DATE" ]]; then
                    timestamp=$(echo "$line" | awk '{print $2}')
                   

                    # Check if timestamp is within the specified range
                    if [[ "$timestamp" > "$START_TIME" || "$timestamp" == "$START_TIME" ]] && [[ "$timestamp" < "$END_TIME" || "$timestamp" == "$END_TIME" ]]; then
                        status=$(echo "$line" | awk '{print $3}')         
                        package_name=$(echo "$line" | awk '{print $4}')   
                        version=$(echo "$line" | awk '{print $5}')   
                    fi
                fi
            fi
        elif [[ $date_format -eq 2 ]]; then  # mmm dd format
            if [[ $line =~ ^[A-Za-z]{3}[[:space:]]+[0-9]{1,2} ]]; then
                log_date="${BASH_REMATCH[0]}"
                date_mmm_dd=$(date -d "$INPUT_DATE" +"%b %d") 

                if [[ "$log_date" == "$date_mmm_dd" ]]; then
                    status=$(echo "$line" | awk '{print $3}')  
                    package_name=$(echo "$line" | awk '{print $4}')  
                fi
            fi
        fi

     
        if [[ -n "$status" && "$status" == "install" || "$status" == "upgrade" || "$status" == "remove" || "$status" == "configure" || "$status" == "unpack" ]]; then
           
            package_actions["$timestamp|$package_name"]="$status" 
           
        fi
    done < "$log_file"



    ACTION_COLORS["install"]="\e[32m" 
    ACTION_COLORS["upgrade"]="\e[34m"   
    ACTION_COLORS["remove"]="\e[31m"   
    ACTION_COLORS["configure"]="\e[35m" 
    ACTION_COLORS["unpack"]="\e[33m"   

   
    if [ ${#package_actions[@]} -eq 0 ]; then
        echo -e "\e[35mNo package actions recorded.\e[0m" 
    else
       
        echo -e "\e[31mPackage Report\e[0m"
        printf "\n"
        printf "%-20s %-20s %-35s %-15s\n" "Date" "Timestamp" "Package Name" "Action Performed"
       printf "%-20s %-20s %-35s %-15s\n" "--------" "-----------" "------------" "----------------"
        
     
        for key in "${!package_actions[@]}"; do
            timestamp="${key%%|*}"
            package_name="${key##*|}"
            date=$(date -d "$timestamp" +"%Y-%m-%d")  

            printf "%-20s %-20s %-35s %-15s\n" "$date" "$timestamp" "$package_name" "${package_actions[$key]}"
        done
    fi
}



main() {
    if [[ -f $LOG_FILE ]]; then
        parse_log "$LOG_FILE"
      

        printf "\n"

        generate_graph

      

    else
        printf "Error: Log file %s not found\n" "$LOG_FILE" >&2
        return 1
    fi
}

main "$@"