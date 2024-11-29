#!/bin/bash

# LOG_FILE="/var/log/syslog"  

# #INPUT_DATE=$1  
# # Parse the start and end dates from command line arguments

# START_DATE=$1
# END_DATE=$2
# START_TIME=$3
# END_TIME=$4

# if [[ $5 != "nofile" ]]; then
#     LOG_FILE=$5
# fi

LOG_FILE="/var/log/syslog"


echo -e "\e[1;36mPlease enter the start date (format: YYYY-MM-DD):\e[0m"
read -p $'\e[1;35mStart Date: \e[0m' START_DATE

echo -e "\e[1;36mPlease enter the end date (format: YYYY-MM-DD):\e[0m"
read -p $'\e[1;35mEnd Date: \e[0m' END_DATE
echo -e "\e[1;36mPlease enter the start time (format: HH:MM:SS):\e[0m"
read -p $'\e[1;35mStart Time: \e[0m' START_TIME

echo -e "\e[1;36mPlease enter the end time (format: HH:MM:SS):\e[0m"
read -p $'\e[1;35mEnd Time: \e[0m' END_TIME

echo -e "\e[1;33mDo you want to specify a custom log file, or use the default log file?\e[0m"
echo -e "\e[1;36m1) Use custom log file\e[0m"
echo -e "\e[1;36m2) Use default log file ($LOG_FILE)\e[0m"
read -p $'\e[1;35mEnter your choice [1-2]: \e[0m' LOG_CHOICE

if [[ "$LOG_CHOICE" -eq 1 ]]; then
    echo -e "\e[1;36mPlease enter the path to your log file:\e[0m"
    read -p $'\e[1;35mLog File Path: \e[0m' LOG_FILE
fi


echo
echo -e "\e[1;32mSelected Parameters:\e[0m"
echo -e "\e[1;34mStart Date: \e[0m$START_DATE"
echo -e "\e[1;34mEnd Date: \e[0m$END_DATE"
echo -e "\e[1;34mStart Time: \e[0m$START_TIME"
echo -e "\e[1;34mEnd Time: \e[0m$END_TIME"
echo -e "\e[1;34mLog File: \e[0m$LOG_FILE"

declare -A SEVERE_ERROR_COUNT
declare -A MILD_ERROR_COUNT
declare -A WARNING_COUNT
SUCCESS_COUNT=0



declare -A OUT_OF_MEMORY_ERRORS
declare -A OOM_ERRORS
declare -A SEGFAULT_ERRORS
declare -A MALLOC_ERRORS
declare -A KERNEL_ERRORS
declare -A CRITICAL_ERRORS
declare -A DISK_IO_ERRORS

declare -A PROCESS_CRASH_ERRORS
declare -A PROCESS_HANG_ERRORS
declare -A PROCESS_KILLED_ERRORS
declare -A CPU_ERRORS
declare -A GPU_ERRORS

categorize_message() {
    local message="$1"
    local category="success"
    if [[ $message =~ (kernel\ bug|process\ crash|process\ hang|process\ killed|CPU\ fault|GPU\ failure|critical|OOM|out\ of\ memory|critical|disk\ failure|I/O\ error) ]]; then
        category="severe_error"
    elif [[ $message =~ (error|fail|failed|CPU\ warning|GPU\ warning|process\ issue) ]]; then
        category="mild_error"
    elif [[ $message =~ (warning|deprecated|high\ usage|not\ recommended) ]]; then
        category="warning"
    fi

    printf "%s\n" "$category"
}
track_specific_errors() {
    local app_name="$1"
    local message="$2"

    if [[ $message =~ (process\ crash) ]]; then
        PROCESS_CRASH_ERRORS["$app_name"]=$((PROCESS_CRASH_ERRORS["$app_name"]+1))
    elif [[ $message =~ (process\ hang) ]]; then
        PROCESS_HANG_ERRORS["$app_name"]=$((PROCESS_HANG_ERRORS["$app_name"]+1))
    elif [[ $message =~ (kernel\ bug|process\ killed) ]]; then
        PROCESS_KILLED_ERRORS["$app_name"]=$((PROCESS_KILLED_ERRORS["$app_name"]+1))
    fi


    if [[ $message =~ (CPU\ fault|CPU\ overload|CPU\ failure) ]]; then
        CPU_ERRORS["$app_name"]=$((CPU_ERRORS["$app_name"]+1))
    fi

    
    if [[ $message =~ (GPU\ failure|GPU\ overload|GPU\ fault) ]]; then
        GPU_ERRORS["$app_name"]=$((GPU_ERRORS["$app_name"]+1))
    fi

    if [[ $message =~ (oom|OOM|out\ of\ memory) ]]; then
        OOM_ERRORS["$app_name"]=$((OOM_ERRORS["$app_name"] + 1))
    elif [[ $message =~ (segfault|Segmentation\ fault) ]]; then
        SEGFAULT_ERRORS["$app_name"]=$((SEGFAULT_ERRORS["$app_name"] + 1))
    elif [[ $message =~ (malloc) ]]; then
        MALLOC_ERRORS["$app_name"]=$((MALLOC_ERRORS["$app_name"] + 1))
    elif [[ $message =~ (kernel\ bug) ]]; then
        KERNEL_ERRORS["$app_name"]=$((KERNEL_ERRORS["$app_name"] + 1))
    elif [[ $message =~ (critical) ]]; then
        CRITICAL_ERRORS["$app_name"]=$((CRITICAL_ERRORS["$app_name"] + 1))
    elif [[ $message =~ (disk\ failure|I/O\ error) ]]; then
        DISK_IO_ERRORS["$app_name"]=$((DISK_IO_ERRORS["$app_name"] + 1))
    fi
}




spin_loader() {
    local pid=$1
    local spin=('|' '/' '-' '\')
    local i=0

    while kill -0 "$pid" 2>/dev/null; do
        printf "\rProcessing log file... ${spin[i]} "
        ((i=(i+1)%4))
        sleep 0.1
    done
    printf "\rProcessing complete.           \n"  # Clean up the line
}





parse_log() {
    local log_file="$LOG_FILE"
    local date_format
    local sample_line


    read -r sample_line < "$log_file"

    if [[ $sample_line =~ ^[A-Za-z]{3}[[:space:]]+[0-9]{1,2} ]]; then
        date_format=2  
    elif [[ $sample_line =~ ^[0-9]{4}-[0-9]{2}-[0-9]{2} ]]; then
        date_format=1  
    else
        echo "Error: Unsupported date format in log file."
        return 1
    fi











    START_DATE_FORMATTED=$(date -d "$START_DATE" +"%Y-%m-%d")
    END_DATE_FORMATTED=$(date -d "$END_DATE" +"%Y-%m-%d")


    while IFS= read -r line; do
        local app_name=""
        local message=""
        local log_date=""

        if [[ $date_format -eq 1 ]]; then  # yyyy-mm-dd format
            if [[ $line =~ ([0-9]{4})-([0-9]{2})-([0-9]{2}) ]]; then
                log_date="${BASH_REMATCH[0]}"


                if [[ "$log_date" > "$END_DATE_FORMATTED" ]]; then
                    break
                fi


                if [[ "$log_date" > "$START_DATE_FORMATTED" ]] && [[ "$log_date" < "$END_DATE_FORMATTED" ]]; then
                    timestamp=$(echo "$line" | awk -F'T' '{print $2}' | cut -d '.' -f 1)


                    if [[ "$timestamp" > "$START_TIME" || "$timestamp" == "$START_TIME" ]] && [[ "$timestamp" < "$END_TIME" || "$timestamp" == "$END_TIME" ]]; then
                        app_name=$(echo "$line" | awk -F '[[:space:]]|\\[' '{print $3}')
                        message=$(echo "$line" | awk -F ']: ' '{gsub(/^ +| +$/, "", $2); print $2}')

                    fi
                fi
            fi
        elif [[ $date_format -eq 2 ]]; then  # mmm dd format
            if [[ $line =~ ^[A-Za-z]{3}[[:space:]]+[0-9]{1,2} ]]; then
                log_date="${BASH_REMATCH[0]}"
                date_mmm_dd_s=$(date -d "$START_DATE" +"%b %e")
                date_mmm_dd_e=$(date -d "$END_DATE" +"%b %e")

                day=$(date -d "$START_DATE" +"%e")
                if [[ $day -lt 10 ]]; then

                    date_mmm_dd_s=$(date -d "$START_DATE" +"%b %e")
                    date_mmm_dd_e=$(date -d "$END_DATE" +"%b %e")
                else

                    date_mmm_dd_s=$(date -d "$START_DATE" +"%b %d")
                    date_mmm_dd_e=$(date -d "$END_DATE" +"%b %d")
                fi

                if [[ "$log_date" > "$date_mmm_dd_e" ]]; then
                    break
                fi


                if [[ "$log_date" > "$date_mmm_dd_s" || "$log_date" == "$date_mmm_dd_s" ]] && [[ "$log_date" < "$date_mmm_dd_e" || "$log_date" == "$date_mmm_dd_e" ]]; then
                    app_name=$(echo "$line" | awk '{print $5}' | cut -d '[' -f 1)
                    message=$(echo "$line" | cut -d ':' -f 3- | sed -e "s/^ *//" -e "s/ *$//")  # Trim whitespaces


                    app_name="${app_name%:}" 
                    app_name="${app_name%[]}"
                    app_name="${app_name%]}"
                # echo "Extracted message: '$message'"  # Debugging statement
                fi
            fi
        fi











        if [[ -n "$message" ]]; then
            local category
            category=$(categorize_message "$message")

            
            track_specific_errors "$app_name" "$message"

            
            case $category in
                "severe_error")
                    SEVERE_ERROR_COUNT["$app_name"]=$((SEVERE_ERROR_COUNT["$app_name"]+1))
                    ;;
                "mild_error")
                ###########################################################################
                    MILD_ERROR_COUNT["$app_name"]=$((MILD_ERROR_COUNT["$app_name"]+1))
                    ;;
                "warning")
                    WARNING_COUNT["$app_name"]=$((WARNING_COUNT["$app_name"]+1))
                    ;;
                "success")
                    SUCCESS_COUNT=$((SUCCESS_COUNT+1))
                    ;;
            esac
        fi
        
    done < "$log_file"
}


print_specific_error_table() {
    printf "\n\e[34mError Table:\e[0m\n"
    printf "%-20s %-15s %-10s %-30s\n" "Error" "App Name" "Count" "Error Message"



    for app in "${!OOM_ERRORS[@]}"; do
        printf "%-20s %-15s %-10d %-30s\n" "oom" "$app" "${OOM_ERRORS[$app]}" "oom"
    done

    
    for app in "${!SEGFAULT_ERRORS[@]}"; do
        printf "%-20s %-15s %-10d %-30s\n" "segfault" "$app" "${SEGFAULT_ERRORS[$app]}" "segfault"
    done

    
    for app in "${!MALLOC_ERRORS[@]}"; do
        printf "%-20s %-15s %-10d %-30s\n" "malloc" "$app" "${MALLOC_ERRORS[$app]}" "malloc"
    done

    
    for app in "${!KERNEL_ERRORS[@]}"; do
        printf "%-20s %-15s %-10d %-30s\n" "kernel bug" "$app" "${KERNEL_ERRORS[$app]}" "kernel bug"
    done

    for app in "${!CRITICAL_ERRORS[@]}"; do
        printf "%-20s %-15s %-10d %-30s\n" "critical" "$app" "${CRITICAL_ERRORS[$app]}" "critical"
    done


    for app in "${!DISK_IO_ERRORS[@]}"; do
        printf "%-20s %-15s %-10d %-30s\n" "disk failure" "$app" "${DISK_IO_ERRORS[$app]}" "disk failure / I/O error"
    done


    if [[ ${#OOM_ERRORS[@]} -eq 0 ]]; then
        printf "%-20s %-15s %-10d %-30s\n" "oom" "N/A" "0" "oom"
    fi
    if [[ ${#SEGFAULT_ERRORS[@]} -eq 0 ]]; then
        printf "%-20s %-15s %-10d %-30s\n" "segfault" "N/A" "0" "segfault"
    fi
    if [[ ${#MALLOC_ERRORS[@]} -eq 0 ]]; then
        printf "%-20s %-15s %-10d %-30s\n" "malloc" "N/A" "0" "malloc"
    fi
    if [[ ${#KERNEL_ERRORS[@]} -eq 0 ]]; then
        printf "%-20s %-15s %-10d %-30s\n" "kernel bug" "N/A" "0" "kernel bug"
    fi
    if [[ ${#CRITICAL_ERRORS[@]} -eq 0 ]]; then
        printf "%-20s %-15s %-10d %-30s\n" "critical" "N/A" "0" "critical"
    fi
    if [[ ${#DISK_IO_ERRORS[@]} -eq 0 ]]; then
        printf "%-20s %-15s %-10d %-30s\n" "disk failure" "N/A" "0" "disk failure / I/O error"
    fi

    for app in "${!PROCESS_CRASH_ERRORS[@]}"; do
        printf "%-20s %-15s %-10d %-30s\n" "process crash" "$app" "${PROCESS_CRASH_ERRORS[$app]}" "process crash"
    done
    for app in "${!PROCESS_HANG_ERRORS[@]}"; do
        printf "%-20s %-15s %-10d %-30s\n" "process hang" "$app" "${PROCESS_HANG_ERRORS[$app]}" "process hang"
    done
    for app in "${!PROCESS_KILLED_ERRORS[@]}"; do
        printf "%-20s %-15s %-10d %-30s\n" "process killed" "$app" "${PROCESS_KILLED_ERRORS[$app]}" "process killed"
    done

    for app in "${!CPU_ERRORS[@]}"; do
        printf "%-20s %-15s %-10d %-30s\n" "cpu error" "$app" "${CPU_ERRORS[$app]}" "cpu fault"
    done


    for app in "${!GPU_ERRORS[@]}"; do
        printf "%-20s %-15s %-10d %-30s\n" "gpu error" "$app" "${GPU_ERRORS[$app]}" "gpu failure"
    done

    if [[ ${#PROCESS_CRASH_ERRORS[@]} -eq 0 ]]; then
        printf "%-20s %-15s %-10d %-30s\n" "process crash" "N/A" "0" "process crash"
    fi
    if [[ ${#PROCESS_HANG_ERRORS[@]} -eq 0 ]]; then
        printf "%-20s %-15s %-10d %-30s\n" "process hang" "N/A" "0" "process hang"
    fi
    if [[ ${#PROCESS_KILLED_ERRORS[@]} -eq 0 ]]; then
        printf "%-20s %-15s %-10d %-30s\n" "process killed" "N/A" "0" "process killed"
    fi
    if [[ ${#CPU_ERRORS[@]} -eq 0 ]]; then
        printf "%-20s %-15s %-10d %-30s\n" "cpu error" "N/A" "0" "cpu fault"
    fi
    if [[ ${#GPU_ERRORS[@]} -eq 0 ]]; then
        printf "%-20s %-15s %-10d %-30s\n" "gpu error" "N/A" "0" "gpu failure"
    fi
}


print_summary() {
    printf "\n\e[34mSummary of Errors and Warnings:\e[0m\n"

    if [[ ${#SEVERE_ERROR_COUNT[@]} -gt 0 ]]; then
        printf "\n\e[31m%-20s %-15s %-20s\e[0m\n" "Error Type" "App Name" "Count"
        printf "%-20s %-15s %-20s\n" "-------------------" "---------------" "-----"
        for entry in $(for app in "${!SEVERE_ERROR_COUNT[@]}"; do
                            echo "$app:${SEVERE_ERROR_COUNT[$app]}"
                        done | sort -t: -k2 -nr); do
            IFS=: read -r app count <<< "$entry"
            printf "%-20s %-15s %-20d\n" "Severe Error" "$app" "$count"
        done
    fi


    if [[ ${#MILD_ERROR_COUNT[@]} -gt 0 ]]; then
        printf "\n\e[91m%-20s %-15s %-20s\e[0m\n" "Error Type" "App Name" "Count"
        printf "%-20s %-15s %-20s\n" "-------------------" "---------------" "-----"
        for entry in $(for app in "${!MILD_ERROR_COUNT[@]}"; do
                            echo "$app:${MILD_ERROR_COUNT[$app]}"
                        done | sort -t: -k2 -nr); do
            IFS=: read -r app count <<< "$entry"
            printf "%-20s %-15s %-20d\n" "Mild Error" "$app" "$count"
        done
    fi


    if [[ ${#WARNING_COUNT[@]} -gt 0 ]]; then
        printf "\n\e[33m%-20s %-15s %-20s\e[0m\n" "Error Type" "App Name" "Count"
        printf "%-20s %-15s %-20s\n" "-------------------" "---------------" "-----"
        for entry in $(for app in "${!WARNING_COUNT[@]}"; do
                            echo "$app:${WARNING_COUNT[$app]}"
                        done | sort -t: -k2 -nr); do
            IFS=: read -r app count <<< "$entry"
            printf "%-20s %-15s %-20d\n" "Warning" "$app" "$count"
        done
    fi


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

    echo "Debug Info: "
    echo "Total Severe Errors: $total_severe_errors"
    echo "Total Mild Errors: $total_mild_errors"
    echo "Total Warnings: $total_warnings"
    printf "\e[32msuccess count:\e[0m %d\n" $(( SUCCESS_COUNT - ${total_severe_errors} - ${total_mild_errors} - ${total_warnings} ))


    printf "\e[32mTotal:\e[0m%d" "$SUCCESS_COUNT"
    printf "\n"

    if [[ -z "$total_severe_errors" || ! "$total_severe_errors" =~ ^[0-9]+$ ]] || \
        [[ -z "$total_mild_errors" || ! "$total_mild_errors" =~ ^[0-9]+$ ]] || \
        [[ -z "$total_warnings" || ! "$total_warnings" =~ ^[0-9]+$ ]] || \
        [[ -z "$SUCCESS_COUNT" || ! "$SUCCESS_COUNT" =~ ^[0-9]+$ ]]; then
        echo "Error: Counts is not valid integers."
        exit 1
    fi
    SUCCESS_COUNT=$(( SUCCESS_COUNT - ${total_severe_errors} - ${total_mild_errors} - ${total_warnings} ))
    max_value=$(echo "$total_severe_errors" "$total_mild_errors" "$total_warnings" "$SUCCESS_COUNT" | awk '{print ($1>$2 && $1>$3 && $1>$4)?$1:($2>$3 && $2>$4)?$2:($3>$4)?$3:$4}')


    if [[ $max_value -eq 0 ]]; then
        echo "No data to display."
        exit 1
    fi

    normalized_severe_errors=$(echo "scale=2; ($total_severe_errors / $max_value) * 120" | bc)
    normalized_mild_errors=$(echo "scale=2; ($total_mild_errors / $max_value) * 120" | bc)
    normalized_warnings=$(echo "scale=2; ($total_warnings / $max_value) * 120" | bc)
    normalized_success=$(echo "scale=2; ($SUCCESS_COUNT / $max_value) * 120" | bc)


    normalized_severe_errors=$(echo "$normalized_severe_errors" | awk '{if ($1 < 1) print 1; else print $1}')
    normalized_mild_errors=$(echo "$normalized_mild_errors" | awk '{if ($1 < 1) print 1; else print $1}')
    normalized_warnings=$(echo "$normalized_warnings" | awk '{if ($1 < 1) print 1; else print $1}')
    normalized_success=$(echo "$normalized_success" | awk '{if ($1 < 1) print 1; else print $1}')





    printf "\nProcess-Related Log Graph:\n"


    printf "Severe Errors:  "
    for ((i=0; i<${normalized_severe_errors%.*}; i++)); do
        printf "\e[31m▅\e[0m"
    done
    printf " $total_severe_errors\n"

    printf "Mild Errors:    "
    for ((i=0; i<${normalized_mild_errors%.*}; i++)); do
        printf "\e[91m▅\e[0m"
    done
    printf " $total_mild_errors\n"



    printf "Warnings:       "
    for ((i=0; i<${normalized_warnings%.*}; i++)); do
        printf "\e[33m▅\e[0m"
    done
    printf " $total_warnings\n"


    printf "Total Success:  "
    for ((i=0; i<${normalized_success%.*}; i++)); do
        printf "\e[32m▅\e[0m"
    done
    printf " $SUCCESS_COUNT\n"


    print_specific_error_table
    printf "\n\n"

}


main() {
    if [[ -f $LOG_FILE ]]; then
        spin_loader $$ &
        spinner_pid=$!
        parse_log "$LOG_FILE"
        print_summary
        kill "$spinner_pid"
        wait "$spinner_pid" 


    else
        printf "Error: Log file %s not found\n" "$LOG_FILE" >&2
        return 1
    fi
}

main "$@"