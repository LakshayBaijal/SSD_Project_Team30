#!/bin/bash

LOG_FILE=""  
INPUT_DATE=$1
START_TIME=$2
END_TIME=$3

if [[ $4 != "nofile" ]]; then
    LOG_FILE=$4
fi
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

    if [[ $message =~ (kernel\ panic|EXC_BAD_ACCESS|EXC_CRASH|kernel\ crash|panic|out\ of\ memory|critical\ error|disk\ failure|I/O\ error|process\ crash|process\ killed|system\ fault) ]]; then
        category="severe_error"
    elif [[ $message =~ (error|fail|failed|crash|terminated|signal\ fault|process\ issue|application\ error|memory\ warning|CPU\ warning|GPU\ warning) ]]; then
        category="mild_error"
    
    elif [[ $message =~ (warning|deprecated|high\ memory\ usage|low\ disk\ space|disk\ warning|not\ recommended|slow\ response) ]]; then
        category="warning"
    fi

    printf "%s\n" "$category"
}
track_specific_errors() {
    local app_name="$1"
    local message="$2"
    if [[ $message =~ (out\ of\ memory|OOM|memory\ pressure|EXC_RESOURCE) ]]; then
        OOM_ERRORS["$app_name"]=$((OOM_ERRORS["$app_name"] + 1))

    elif [[ $message =~ (segfault|EXC_CRASH|EXC_BAD_ACCESS|core\ dump) ]]; then
        SEGFAULT_ERRORS["$app_name"]=$((SEGFAULT_ERRORS["$app_name"] + 1))

    elif [[ $message =~ (malloc\ error|memory\ allocation\ failure) ]]; then
        MALLOC_ERRORS["$app_name"]=$((MALLOC_ERRORS["$app_name"] + 1))

    elif [[ $message =~ (kernel\ panic|panic|EXC_BAD_ACCESS|EXC_CRASH) ]]; then
        KERNEL_ERRORS["$app_name"]=$((KERNEL_ERRORS["$app_name"] + 1))

    elif [[ $message =~ (critical\ error|fatal\ error|system\ failure|unhandled\ exception|system\ fault) ]]; then
        CRITICAL_ERRORS["$app_name"]=$((CRITICAL_ERRORS["$app_name"] + 1))

    elif [[ $message =~ (disk\ failure|I/O\ error|disk\ read\ error|disk\ write\ error) ]]; then
        DISK_IO_ERRORS["$app_name"]=$((DISK_IO_ERRORS["$app_name"] + 1))
    fi

    if [[ $message =~ (process\ crash|terminated\ due\ to\ signal|terminated\ by\ signal) ]]; then
        PROCESS_CRASH_ERRORS["$app_name"]=$((PROCESS_CRASH_ERRORS["$app_name"]+1))
    elif [[ $message =~ (process\ hang|process\ freeze) ]]; then
        PROCESS_HANG_ERRORS["$app_name"]=$((PROCESS_HANG_ERRORS["$app_name"]+1))
    elif [[ $message =~ (process\ killed|killed\ by\ signal) ]]; then
        PROCESS_KILLED_ERRORS["$app_name"]=$((PROCESS_KILLED_ERRORS["$app_name"]+1))
    fi

    if [[ $message =~ (CPU\ fault|CPU\ overload|CPU\ failure|CPU\ panic) ]]; then
        CPU_ERRORS["$app_name"]=$((CPU_ERRORS["$app_name"]+1))
    fi

    if [[ $message =~ (GPU\ failure|GPU\ overload|GPU\ fault|GPU\ panic) ]]; then
        GPU_ERRORS["$app_name"]=$((GPU_ERRORS["$app_name"]+1))
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
    printf "\rProcessing complete.           \n"
}

parse_log() {
    echo 
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

    while IFS= read -r line; do
        local app_name=""
        local message=""

        if [[ $date_format -eq 1 ]]; then
            if [[ $line =~ ([0-9]{4})-([0-9]{2})-([0-9]{2}) ]]; then
                log_date="${BASH_REMATCH[0]}"

                if [[ "$log_date" == "$INPUT_DATE" ]]; then
                    timestamp=$(echo "$line" | awk -F'T' '{print $2}' | cut -d '.' -f 1)

                    
                    if [[ "$timestamp" > "$START_TIME" || "$timestamp" == "$START_TIME" ]] && [[ "$timestamp" < "$END_TIME" || "$timestamp" == "$END_TIME" ]]; then
                        app_name=$(echo "$line" | awk -F '[[:space:]]|\\[' '{print $3}')
                        message=$(echo "$line" | awk -F ']: ' '{gsub(/^ +| +$/, "", $2); print $2}')
                    fi
                fi
            fi
        elif [[ $date_format -eq 2 ]]; then
            if [[ $line =~ ^[A-Za-z]{3}[[:space:]]+[0-9]{1,2} ]]; then
                log_date="${BASH_REMATCH[0]}"
                date_mmm_dd=$(date -d "$INPUT_DATE" +"%b %d")
                
                
        day=$(date -d "$INPUT_DATE" +"%d")

        day=${day#0}

        if [[ $day -lt 10 ]]; then
            date_mmm_dd=$(date -d "$INPUT_DATE" +"%b %e")
        else
            date_mmm_dd=$(date -d "$INPUT_DATE" +"%b %d")
        fi
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
    printf "\n\e[35mError Table:\e[0m\n"
    echo
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
    echo
    printf "\n\e[35mSummary of Errors and Warnings:\e[0m\n"
    echo
        echo
        if [[ ${#SEVERE_ERROR_COUNT[@]} -gt 0 ]]; then
            printf "\e[31msevere errors:\e[0m\n"
            printf "%-20s %-30s\n" "Application" "Severe Error Count"
            printf "%-20s %-30s\n" "------------" "------------------"
            for app in "${!SEVERE_ERROR_COUNT[@]}"; do
                printf "%-20s %-20d\n" "$app" "${SEVERE_ERROR_COUNT[$app]}"
            done
        fi

        echo
        # Print mild errors in a table format
        if [[ ${#MILD_ERROR_COUNT[@]} -gt 0 ]]; then
            printf "\e[91mmild errors:\e[0m\n"
            printf "%-30s %-20s\n" "Application" "Mild Error Count"
            printf "%-30s %-20s\n" "------------" "----------------"
            for app in "${!MILD_ERROR_COUNT[@]}"; do
                printf "%-30s %-20d\n" "$app" "${MILD_ERROR_COUNT[$app]}"
            done | column -t
        fi
        echo
        if [[ ${#WARNING_COUNT[@]} -gt 0 ]]; then
            printf "\e[33mwarning:\e[0m\n"
            printf "%-44s %-30s\n" "Application" "Warning Count"
            printf "%-44s %-30s\n" "------------" "-------------"
            for app in "${!WARNING_COUNT[@]}"; do
                printf "%-44s %-30d\n" "$app" "${WARNING_COUNT[$app]}"
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
    echo 
    echo

    printf "\e[32msuccess count:\e[0m %d\n" $(( SUCCESS_COUNT - ${total_severe_errors} - ${total_mild_errors} - ${total_warnings} ))
    printf "\e[32mtotal:\e[0m%d" "$SUCCESS_COUNT"
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
    
    normalized_severe_errors=$(echo "scale=2; ($total_severe_errors / $max_value) * 120" | bc)
    normalized_mild_errors=$(echo "scale=2; ($total_mild_errors / $max_value) * 120" | bc)
    normalized_warnings=$(echo "scale=2; ($total_warnings / $max_value) * 120" | bc)
    normalized_success=$(echo "scale=2; ($SUCCESS_COUNT / $max_value) * 120" | bc)

    echo
    printf "\n\e[1;38;2;195;43;237mGraph:\n\e[0m"
    echo

    printf "Severe Errors:  "
    printf "\e[31m▅\e[0m"
    for ((i=0; i<${normalized_severe_errors%.*}; i++)); do
        printf "\e[31m▅\e[0m"
    done
    printf "$total_severe_errors"
    printf "\n"
    printf "Mild Errors:    "
    printf "\e[91m▅\e[0m"
    for ((i=0; i<${normalized_mild_errors%.*}; i++)); do
        printf "\e[91m▅\e[0m"
    done
    printf "$total_mild_errors"
    printf "\n"

    printf "Warnings:       "
    printf "\e[33m▅\e[0m"
    for ((i=0; i<${normalized_warnings%.*}; i++)); do
        printf "\e[33m▅\e[0m"
    done
    printf "$total_warnings"
    printf "\n"


    printf "Success:        "

    for ((i=0; i<${normalized_success%.*} && i<100; i++)); do
        printf "\e[32m▅\e[0m"
        if [[ $i -ge 100 ]]; then
            break
        fi
    done
    printf "$SUCCESS_COUNT"
    printf "\n"
    print_specific_error_table
    printf "\n"

}


main() {
    if [[ -f $LOG_FILE ]]; then

        spin_loader $$ &
        spinner_pid=$!

        parse_log "$LOG_FILE"
        
        kill "$spinner_pid"
        wait "$spinner_pid"
        print_summary
    else
        printf "Error: Log file %s not found\n" "$LOG_FILE" >&2
        return 1
    fi
}

main "$@"
