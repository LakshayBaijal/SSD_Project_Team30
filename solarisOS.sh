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

declare -A PROCESS_CRASH_ERRORS
declare -A PROCESS_HANG_ERRORS
declare -A PROCESS_KILLED_ERRORS
declare -A CPU_ERRORS
declare -A GPU_ERRORS

declare -A PAM_ERRORS
declare -A LOGIN_FAILURES

declare -A ACCOUNT_DISABLED_ERRORS
declare -A CONNECTION_ISSUES

declare -A FTP_TRANSACTIONS


categorize_message() {
    local message="$1"
    local category="success" 

    if [[ $message =~ (kernel\ bug|OOM|out\ of\ memory|critical|disk\ failure|I/O\ error|process\ crash|process\ hang|process\ killed|CPU\ fault|GPU\ failure|fatal|PAM_ERROR_MSG|Account\ is\ disabled|authentication\ failed|disk\ corruption) ]]; then
        category="severe_error"
    elif [[ $message =~ (error|fail|failed|CPU\ warning|GPU\ warning|process\ issue|login\ failure|connection\ refused) ]]; then
        category="mild_error"
    elif [[ $message =~ (warning|deprecated|high\ usage|not\ recommended|repeated\ login\ failures|performance\ degradation) ]]; then
        category="warning"
    fi

    printf "%s\n" "$category"
}
track_specific_errors() {
    local app_name="$1"
    local message="$2"
    if [[ $message =~ (out\ of\ memory) ]]; then
        OUT_OF_MEMORY_ERRORS["$app_name"]=$((OUT_OF_MEMORY_ERRORS["$app_name"] + 1))
    elif [[ $message =~ (oom|OOM) ]]; then
        OOM_ERRORS["$app_name"]=$((OOM_ERRORS["$app_name"] + 1))
    elif [[ $message =~ (segfault|Segmentation\ fault) ]]; then
        SEGFAULT_ERRORS["$app_name"]=$((SEGFAULT_ERRORS["$app_name"] + 1))
    elif [[ $message =~ (malloc) ]]; then
        MALLOC_ERRORS["$app_name"]=$((MALLOC_ERRORS["$app_name"] + 1))
    fi

    if [[ $message =~ (PAM_ERROR_MSG) ]]; then
        PAM_ERRORS["$app_name"]=$((PAM_ERRORS["$app_name"] + 1))
    elif [[ $message =~ (repeated\ login\ failures) ]]; then
        LOGIN_FAILURES["$app_name"]=$((LOGIN_FAILURES["$app_name"] + 1))
    elif [[ $message =~ (Account\ is\ disabled) ]]; then
        ACCOUNT_DISABLED_ERRORS["$app_name"]=$((ACCOUNT_DISABLED_ERRORS["$app_name"] + 1))
    fi
    if [[ $message =~ (connection\ from|refused\ connect\ from) ]]; then
        CONNECTION_ISSUES["$app_name"]=$((CONNECTION_ISSUES["$app_name"] + 1))
    fi

    if [[ $message =~ (FTPD:\ IMPORT|FTPD:\ EXPORT) ]]; then
        FTP_TRANSACTIONS["$app_name"]=$((FTP_TRANSACTIONS["$app_name"] + 1))
    fi
    if [[ $message =~ (CPU\ fault|CPU\ overload|CPU\ failure) ]]; then
        CPU_ERRORS["$app_name"]=$((CPU_ERRORS["$app_name"] + 1))
    fi

    if [[ $message =~ (GPU\ failure|GPU\ overload|GPU\ fault) ]]; then
        GPU_ERRORS["$app_name"]=$((GPU_ERRORS["$app_name"] + 1))
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
                date_mmm_dd=$(date -d "$INPUT_DATE" +"%b %d")\
                
            day=$(date -d "$INPUT_DATE" +"%d")
            if [[ ${day} -lt 10 ]]; then
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
        
        
        # echo "$category"

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
    echo
    printf "\n\e[33mError Table:\e[0m\n"
    echo
    printf "%-20s %-15s %-10s %-30s\n" "Error" "App Name" "Count" "Error Message"
    echo
    for app in "${!OUT_OF_MEMORY_ERRORS[@]}"; do
        printf "%-20s %-15s %-10d %-30s\n" "out of memory" "$app" "${OUT_OF_MEMORY_ERRORS[$app]}" "out of memory"
    done

    for app in "${!OOM_ERRORS[@]}"; do
        printf "%-20s %-15s %-10d %-30s\n" "oom" "$app" "${OOM_ERRORS[$app]}" "oom"
    done
    for app in "${!SEGFAULT_ERRORS[@]}"; do
        printf "%-20s %-15s %-10d %-30s\n" "segfault" "$app" "${SEGFAULT_ERRORS[$app]}" "segfault"
    done

    for app in "${!MALLOC_ERRORS[@]}"; do
        printf "%-20s %-15s %-10d %-30s\n" "malloc" "$app" "${MALLOC_ERRORS[$app]}" "malloc"
    done

    
    for app in "${!PAM_ERRORS[@]}"; do
        printf "%-20s %-15s %-10d %-30s\n" "PAM error" "$app" "${PAM_ERRORS[$app]}" "PAM_ERROR_MSG"
    done
    for app in "${!LOGIN_FAILURES[@]}"; do
        printf "%-20s %-15s %-10d %-30s\n" "login failure" "$app" "${LOGIN_FAILURES[$app]}" "repeated login failures"
    done
    for app in "${!ACCOUNT_DISABLED_ERRORS[@]}"; do
        printf "%-20s %-15s %-10d %-30s\n" "account disabled" "$app" "${ACCOUNT_DISABLED_ERRORS[$app]}" "Account is disabled"
    done
    for app in "${!CONNECTION_ISSUES[@]}"; do
        printf "%-20s %-15s %-10d %-30s\n" "connection issue" "$app" "${CONNECTION_ISSUES[$app]}" "connection refused or denied"
    done

    for app in "${!CPU_ERRORS[@]}"; do
        printf "%-20s %-15s %-10d %-30s\n" "cpu error" "$app" "${CPU_ERRORS[$app]}" "cpu fault"
    done


    for app in "${!GPU_ERRORS[@]}"; do
        printf "%-20s %-15s %-10d %-30s\n" "gpu error" "$app" "${GPU_ERRORS[$app]}" "gpu failure"
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
    if [[ ${#PAM_ERRORS[@]} -eq 0 ]]; then
        printf "%-20s %-15s %-10d %-30s\n" "PAM error" "N/A" "0" "PAM_ERROR_MSG"
    fi
    if [[ ${#LOGIN_FAILURES[@]} -eq 0 ]]; then
        printf "%-20s %-15s %-10d %-30s\n" "login failure" "N/A" "0" "repeated login failures"
    fi
    if [[ ${#ACCOUNT_DISABLED_ERRORS[@]} -eq 0 ]]; then
        printf "%-20s %-15s %-10d %-30s\n" "account disabled" "N/A" "0" "Account is disabled"
    fi
    if [[ ${#CONNECTION_ISSUES[@]} -eq 0 ]]; then
        printf "%-20s %-15s %-10d %-30s\n" "connection issue" "N/A" "0" "connection refused or denied"
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
    printf "\n\e[34mSummary of Errors and Warnings:\e[0m\n"
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
        if [[ ${#MILD_ERROR_COUNT[@]} -gt 0 ]]; then
            printf "\e[91mmild errors:\e[0m\n"
            printf "%-20s %-30s\n" "Application" "Mild Error Count"
            printf "%-20s %-30s\n" "------------" "----------------"
            for app in "${!MILD_ERROR_COUNT[@]}"; do
                printf "%-20s %-20d\n" "$app" "${MILD_ERROR_COUNT[$app]}"
            done 
        fi

        echo
        if [[ ${#WARNING_COUNT[@]} -gt 0 ]]; then
            printf "\e[33mwarning:\e[0m\n"
            printf "%-20s %-30s\n" "Application" "Warning Count"
            printf "%-20s %-30s\n" "------------" "-------------"
            for app in "${!WARNING_COUNT[@]}"; do
                printf "%-20s %-30d\n" "$app" "${WARNING_COUNT[$app]}"
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
    echo
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

    printf "\nGraph:\n"

    printf "Severe Errors:  "
    printf "\e[31m▅\e[0m"
    for ((i=0; i<${normalized_severe_errors%.*}; i++)); do
        printf "\e[31m▅\e[0m"
    done
    printf "$total_sever_errors"
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

    printf "Success :         "
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
