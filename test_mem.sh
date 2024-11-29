#!/bin/bash

LOG_FILE="/var/log/syslog"  
INPUT_DATE=$1  
START_TIME=$2
END_TIME=$3

# Check if log file exists
if [[ ! -f "$LOG_FILE" ]]; then
    echo "Error: Log file not found: $LOG_FILE"
    exit 1
fi


declare -A SEVERE_ERROR_COUNT
declare -A MILD_ERROR_COUNT
declare -A WARNING_COUNT
SUCCESS_COUNT=0


declare -A OUT_OF_MEMORY_ERRORS
declare -A OOM_ERRORS
declare -A SEGFAULT_ERRORS
declare -A MALLOC_ERRORS


categorize_message() {
    local message="$1"
    local category="success"  

    # Check for severe and mild error keywords
    if [[ $message =~ (kernel\ bug|OOM|out\ of\ memory|critical|disk\ failure|I/O\ error) ]]; then
        category="severe_error"
    elif [[ $message =~ (error|fail|failed) ]]; then
        category="mild_error"
    elif [[ $message =~ (warning|deprecated|high\ usage|not\ recommended) ]]; then
        category="warning"
    fi

    printf "%s\n" "$category"
}

# Function to track specific errors
track_specific_errors() {
    local app_name="$1"
    local message="$2"

    # Check and store specific errors
    if [[ $message =~ (out\ of\ memory) ]]; then
        OUT_OF_MEMORY_ERRORS["$app_name"]=$((OUT_OF_MEMORY_ERRORS["$app_name"] + 1))
    elif [[ $message =~ (oom|OOM) ]]; then
        OOM_ERRORS["$app_name"]=$((OOM_ERRORS["$app_name"] + 1))
    elif [[ $message =~ (segfault|Segmentation\ fault) ]]; then
        SEGFAULT_ERRORS["$app_name"]=$((SEGFAULT_ERRORS["$app_name"] + 1))
    elif [[ $message =~ (malloc) ]]; then
        MALLOC_ERRORS["$app_name"]=$((MALLOC_ERRORS["$app_name"] + 1))
    fi
}


parse_log() {
    local log_file="$LOG_FILE"
    local date_format
    local sample_line

    #  determine its date format
    read -r sample_line < "$log_file"

 
    if [[ $sample_line =~ ^[A-Za-z]{3}[[:space:]]+[0-9]{1,2} ]]; then
        date_format=2  
    elif [[ $sample_line =~ ^[0-9]{4}-[0-9]{2}-[0-9]{2} ]]; then
        date_format=1  
    else
        echo "Error: Unsupported date format in log file."
        return 1
    fi

 
    while IFS= read -r line; do
        local app_name=""
        local message=""

        if [[ $date_format -eq 1 ]]; then  # yyyy-mm-dd format
            if [[ $line =~ ([0-9]{4})-([0-9]{2})-([0-9]{2}) ]]; then
                log_date="${BASH_REMATCH[0]}"
                     
                if [[ "$log_date" == "$INPUT_DATE" ]]; then
                    timestamp=$(echo "$line" | awk -F'T' '{print $2}' | cut -d '.' -f 1)

                    # Check if timestamp is within the specified range
                if [[ "$timestamp" > "$START_TIME" || "$timestamp" == "$START_TIME" ]] && [[ "$timestamp" < "$END_TIME" || "$timestamp" == "$END_TIME" ]]; then
                    app_name=$(echo "$line" | awk -F '[[:space:]]|\\[' '{print $3}')  
                    message=$(echo "$line" | awk -F ']: ' '{gsub(/^ +| +$/, "", $2); print $2}')  
                    
                fi
                fi
            fi
        elif [[ $date_format -eq 2 ]]; then  # mmm dd format
            if [[ $line =~ ^[A-Za-z]{3}[[:space:]]+[0-9]{1,2} ]]; then
                log_date="${BASH_REMATCH[0]}"
                date_mmm_dd=$(date -d "$INPUT_DATE" +"%b %d")  # Convert INPUT_DATE to mmm dd format

                if [[ "$log_date" == "$date_mmm_dd" ]]; then
                    app_name=$(echo "$line" | awk '{print $5}' | cut -d '[' -f 1)
                    message=$(echo "$line" | cut -d ':' -f 3- | sed -e "s/^ *//" -e "s/ *$//")  

            
                    app_name="${app_name%:}"        
                    app_name="${app_name%[]}"
                    app_name="${app_name%]}"       
             
                fi
            fi
        fi

      
        if [[ -n "$message" ]]; then
           
            local category
                  
            category=$(categorize_message "$message")
          
          
       
            track_specific_errors "$app_name" "$message"

        
            case $category in
                "severe_error")
                    SEVERE_ERROR_COUNT["$app_name"]=$((SEVERE_ERROR_COUNT["$app_name"] + 1))
                    ;;
                "mild_error")
                    MILD_ERROR_COUNT["$app_name"]=$((MILD_ERROR_COUNT["$app_name"] + 1))
                    ;;
                "warning")
                    WARNING_COUNT["$app_name"]=$((WARNING_COUNT["$app_name"] + 1))
                    ;;
                "success")
                    SUCCESS_COUNT=$((SUCCESS_COUNT + 1))
                    ;;
            esac
        fi
        
    done < "$LOG_FILE"
}



print_specific_error_table() {
    printf "\n\e[34mError Table:\e[0m\n"
    printf "%-20s %-15s %-10s %-30s\n" "Error" "App Name" "Count" "Error Message"

    # For out of memory errors
    for app in "${!OUT_OF_MEMORY_ERRORS[@]}"; do
        printf "%-20s %-15s %-10d %-30s\n" "out of memory" "$app" "${OUT_OF_MEMORY_ERRORS[$app]}" "out of memory"
    done

    # For OOM errors
    for app in "${!OOM_ERRORS[@]}"; do
        printf "%-20s %-15s %-10d %-30s\n" "oom" "$app" "${OOM_ERRORS[$app]}" "oom"
    done

    # For segfault errors
    for app in "${!SEGFAULT_ERRORS[@]}"; do
        printf "%-20s %-15s %-10d %-30s\n" "segfault" "$app" "${SEGFAULT_ERRORS[$app]}" "segfault"
    done

    # For malloc errors
    for app in "${!MALLOC_ERRORS[@]}"; do
        printf "%-20s %-15s %-10d %-30s\n" "malloc" "$app" "${MALLOC_ERRORS[$app]}" "malloc"
    done


    if [[ ${#OUT_OF_MEMORY_ERRORS[@]} -eq 0 ]]; then
        printf "%-20s %-15s %-10d %-30s\n" "out of memory" "N/A" "0" "out of memory"
    fi
    if [[ ${#OOM_ERRORS[@]} -eq 0 ]]; then
        printf "%-20s %-15s %-10d %-30s\n" "oom" "N/A" "0" "oom"
    fi
    if [[ ${#SEGFAULT_ERRORS[@]} -eq 0 ]]; then
        printf "%-20s %-15s %-10d %-30s\n" "segfault" "N/A" "0" "segfault"
    fi
    if [[ ${#MALLOC_ERRORS[@]} -eq 0 ]]; then
        printf "%-20s %-15s %-10d %-30s\n" "malloc" "N/A" "0" "malloc"
    fi
}

print_summary() {
    printf "\n\e[34mSummary of Errors and Warnings:\e[0m\n"

    #  severe errors
    if [[ ${#SEVERE_ERROR_COUNT[@]} -gt 0 ]]; then
        printf "\e[31msevere errors:\e[0m\n"
        for app in "${!SEVERE_ERROR_COUNT[@]}"; do
            printf "%s: severe error count %d\n" "$app" "${SEVERE_ERROR_COUNT[$app]}"
        done
    fi

    #  mild errors
    if [[ ${#MILD_ERROR_COUNT[@]} -gt 0 ]]; then
        printf "\e[91mmild errors:\e[0m\n"
        for app in "${!MILD_ERROR_COUNT[@]}"; do
            printf "%s: mild error count %d\n" "$app" "${MILD_ERROR_COUNT[$app]}"
        done
    fi

    #  warnings
    if [[ ${#WARNING_COUNT[@]} -gt 0 ]]; then
        printf "\e[33mwarning:\e[0m\n"
        for app in "${!WARNING_COUNT[@]}"; do
            printf "%s: warning count %d\n" "$app" "${WARNING_COUNT[$app]}"
        done
    fi

    #  success count
    printf "\e[32msuccess count:\e[0m %d\n" "$SUCCESS_COUNT"

    printf "\e[32mtotal:\e[0m\n%d\n" "$SUCCESS_COUNT"

    total_severe_errors=0
    for count in "${SEVERE_ERROR_COUNT[@]}"; do
        total_severe_errors=$((total_severe_errors + count))
    done

    total_mild_errors=0
    for count in "${MILD_ERROR_COUNT[@]}"; do
        total_mild_errors=$((total_mild_errors + count))
    done

    total_warnings=0
    for count in "${WARNING_COUNT[@]}"; do
        total_warnings=$((total_warnings + count))
    done

 
    max_value=$(echo "$total_severe_errors" "$total_mild_errors" "$total_warnings" "$SUCCESS_COUNT" | awk '{print ($1>$2 && $1>$3 && $1>$4)?$1:($2>$3 && $2>$4)?$2:($3>$4)?$3:$4}')
    

    normalized_severe_errors=$(echo "scale=2; ($total_severe_errors / $max_value) * 120 + 1" | bc)
    normalized_mild_errors=$(echo "scale=2; ($total_mild_errors / $max_value) * 120" | bc)
    normalized_warnings=$(echo "scale=2; ($total_warnings / $max_value) * 120" | bc)
    normalized_success=$(echo "scale=2; ($SUCCESS_COUNT / $max_value) * 120" | bc)

 printf "\nGraph:\n"

printf "Severe Errors:  "
for ((i=0; i<${normalized_severe_errors%.*}; i++)); do
    printf "\e[31m▅\e[0m"
done
printf "$total_sever_errors"
printf "\n"

printf "Mild Errors:    "
for ((i=0; i<${normalized_mild_errors%.*}; i++)); do
    printf "\e[91m▅\e[0m"
done
printf "$total_mild_errors"
printf "\n"

printf "Warnings:       "
for ((i=0; i<${normalized_warnings%.*}; i++)); do
    printf "\e[33m▅\e[0m"
done
printf "$total_warnings"
printf "\n"

printf "Total :         "
for ((i=0; i<${normalized_success%.*}; i++)); do
    printf "\e[32m▅\e[0m"
done
printf "$SUCCESS_COUNT"
printf "\n"

print_specific_error_table
printf "\n"

memory_used=$(free -h | grep Mem | awk '{print $3}' | sed 's/G/ /' | awk '{print $1*1024}')
memory_total=$(free -h | grep Mem | awk '{print $2}' | sed 's/G/ /' | awk '{print $1*1024}')
memory_percentage=$(echo "scale=2; $memory_used * 100 / $memory_total" | bc)

if (( $(echo "$memory_percentage > 75" | bc -l) )); then
    echo -e "\e[31mMemory Usage: Used: ${memory_used}MB / Total: ${memory_total}MB (High)\e[0m"
elif (( $(echo "$memory_percentage > 50" | bc -l) )); then
    echo -e "\e[33mMemory Usage: Used: ${memory_used}MB / Total: ${memory_total}MB (Moderate)\e[0m"
else
    echo -e "\e[32mMemory Usage: Used: ${memory_used}MB / Total: ${memory_total}MB (Normal)\e[0m"
fi

disk_usage=$(df -h --output=pcent | grep -Eo '[0-9]+' | head -n 1)
if [[ -n "$disk_usage" && "$disk_usage" =~ ^[0-9]+$ ]]; then
    if (( disk_usage > 80 )); then
        echo -e "\e[31mDisk Usage: ${disk_usage}% (High)\e[0m"
    else
        echo -e "\e[32mDisk Usage: ${disk_usage}% (Normal)\e[0m"
    fi
else
    echo "Could not retrieve disk usage."
fi

swap_usage=$(free -h | grep Swap | awk '{print $3}' | sed 's/G/ /' | awk '{print $1*1024}')
swap_total=$(free -h | grep Swap | awk '{print $2}' | sed 's/G/ /' | awk '{print $1*1024}')
swap_percentage=$(echo "scale=2; $swap_usage * 100 / $swap_total" | bc)

if (( $(echo "$swap_percentage > 75" | bc -l) )); then
    echo -e "\e[31mSwap Usage: Used: ${swap_usage}MB / Total: ${swap_total}MB (High)\e[0m"
else
    echo -e "\e[32mSwap Usage: Used: ${swap_usage}MB / Total: ${swap_total}MB (Normal)\e[0m"
fi

}

main() {
    if [[ -f $LOG_FILE ]]; then
        parse_log "$LOG_FILE"
        print_summary

        printf "\n"
        printf "Memory and paging details for interval\n"
        sar -r -B -W -s "$START_TIME" -e "$END_TIME" -i 1800 --human --pretty

    else
        printf "Error: Log file %s not found\n" "$LOG_FILE" >&2
        return 1
    fi
}

main "$@"
