#!/bin/bash

if [ "$#" -ne 4 ]; then
    echo "Usage: $0 <date> <start_time> <end_time> <log_file>"
    echo "Example: $0 28-09-2016 00:00:00 23:59:59 Windows_2k.log"
    exit 1
fi

DATE=$1
START_TIME=$2
END_TIME=$3
LOG_FILE=$4

# Accept both dd-mm-yyyy and yyyy-mm-dd formats
if [[ $DATE =~ ^[0-9]{2}-[0-9]{2}-[0-9]{4}$ ]]; then
    DATE=$(date -d "$DATE" +"%Y-%m-%d")
elif [[ $DATE =~ ^[0-9]{4}-[0-9]{2}-[0-9]{2}$ ]]; then
    DATE=$(date -d "$DATE" +"%Y-%m-%d")
else
    echo "Invalid date format. Please provide the date in dd-mm-yyyy or yyyy-mm-dd format."
    exit 1
fi

if [[ $4 != "nofile" ]]; then
    LOG_FILE=$4
fi

if [ ! -f "$LOG_FILE" ]; then
    echo "Error: Log file '$LOG_FILE' not found."
    exit 1
fi

START_EPOCH=$(date -d "$DATE $START_TIME" +%s)
END_EPOCH=$(date -d "$DATE $END_TIME" +%s)

declare -A SEVERE_ERROR_COUNT
declare -A MILD_ERROR_COUNT
declare -A WARNING_COUNT
SUCCESS_COUNT=0

declare -A SPECIFIC_ERRORS

categorize_message() {
    local message="$1"
    local category="success"

    if [[ $message =~ (Error|E_FAIL|CBS_E_|FATAL|CRITICAL) ]]; then
        category="severe_error"
    elif [[ $message =~ (Failed|HRESULT) ]]; then
        category="mild_error"
    elif [[ $message =~ (Warning|WARN) ]]; then
        category="warning"
    fi

    echo "$category"
}

track_specific_errors() {
    local app_name="$1"
    local message="$2"

    if [[ $message =~ HRESULT[[:space:]]*=[[:space:]]*([^\]]+) ]]; then
        hresult_code="${BASH_REMATCH[1]}"

        case "$hresult_code" in
            "0x80004005")
                hresult="$hresult_code - E_FAIL"
                ;;
            "0x800f080d")
                hresult="$hresult_code - CBS_E_MANIFEST_INVALID_ITEM"
                ;;
            "0x800f0805")
                hresult="$hresult_code - CBS_E_INVALID_PACKAGE"
                ;;
            *)
                hresult="$hresult_code"
                ;;
        esac

        SPECIFIC_ERRORS["$hresult"]=$((SPECIFIC_ERRORS["$hresult"] + 1))
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

    while IFS= read -r line; do
        if [[ $line =~ ^([0-9]{4}-[0-9]{2}-[0-9]{2})[[:space:]]+([0-9]{2}:[0-9]{2}:[0-9]{2}),[[:space:]]+([A-Za-z]+)[[:space:]]+([A-Za-z0-9_]+)[[:space:]]+(.*)$ ]]; then
            log_date="${BASH_REMATCH[1]}"
            log_time="${BASH_REMATCH[2]}"
            log_level="${BASH_REMATCH[3]}"
            app_name="${BASH_REMATCH[4]}"
            message="${BASH_REMATCH[5]}"

            log_epoch=$(date -d "$log_date $log_time" +%s)

            if [[ $log_epoch -ge $START_EPOCH && $log_epoch -le $END_EPOCH ]]; then
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
        fi
    done < "$log_file"
}

print_summary() {
    echo
    echo -e "\e[35mSummary of Errors and Warnings:\e[0m"
    echo

    if [[ ${#SEVERE_ERROR_COUNT[@]} -gt 0 ]]; then
        echo -e "\e[31mSevere Errors:\e[0m"
        echo
        printf "%-20s %-20s\n" "Application" "Severe Error Count"
        printf "%-20s %-20s\n" "------------" "------------------"
        for app in "${!SEVERE_ERROR_COUNT[@]}"; do
            printf "%-20s %-20d\n" "$app" "${SEVERE_ERROR_COUNT[$app]}"
        done | sort -k2 -n -r
        echo
    fi

    if [[ ${#MILD_ERROR_COUNT[@]} -gt 0 ]]; then
        echo -e "\e[91mMild Errors:\e[0m"
        echo
        printf "%-20s %-20s\n" "Application" "Mild Error Count"
        printf "%-20s %-20s\n" "------------" "----------------"
        for app in "${!MILD_ERROR_COUNT[@]}"; do
            printf "%-20s %-20d\n" "$app" "${MILD_ERROR_COUNT[$app]}"
        done | sort -k2 -n -r
        echo
    fi

    if [[ ${#WARNING_COUNT[@]} -gt 0 ]]; then
        echo -e "\e[33mWarnings:\e[0m"
        echo
        printf "%-20s %-20s\n" "Application" "Warning Count"
        printf "%-20s %-20s\n" "------------" "-------------"
        for app in "${!WARNING_COUNT[@]}"; do
            printf "%-20s %-20d\n" "$app" "${WARNING_COUNT[$app]}"
        done | sort -k2 -n -r
        echo
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

    echo -e "\e[32mSuccess Count:\e[0m $SUCCESS_COUNT"
    total_logs=$((SUCCESS_COUNT + total_severe_errors + total_mild_errors + total_warnings))
    echo -e "\e[32mTotal:\e[0m $total_logs"
}

print_specific_error_table() {
    echo
    echo -e "\e[35mError Table:\e[0m"
    echo
    printf "%-40s %-15s %-10s %-30s\n" "Error" "App Name" "Count" "Error Message"

    for hresult in "${!SPECIFIC_ERRORS[@]}"; do
        error_message=$(echo "$hresult" | sed 's/^.* - //')

        printf "%-40s %-15s %-10d %-30s\n" "$error_message" "N/A" "${SPECIFIC_ERRORS[$hresult]}" "$error_message"
    done
}

print_graph() {
    echo
    echo -e "\e[1;38;2;195;43;237mGraph:\n\e[0m"

    max_value=1
    for value in "$SUCCESS_COUNT" "$total_severe_errors" "$total_mild_errors" "$total_warnings"; do
        if [[ $value -gt $max_value ]]; then
            max_value=$value
        fi
    done
    normalized_severe_errors=$(( (total_severe_errors * 50) / max_value ))
    normalized_mild_errors=$(( (total_mild_errors * 50) / max_value ))
    normalized_warnings=$(( (total_warnings * 50) / max_value ))
    normalized_success=$(( (SUCCESS_COUNT * 50) / max_value ))

    printf "Severe Errors:  "
    printf "\e[31m"
    for ((i=0; i<normalized_severe_errors; i++)); do
        printf "▅"
    done
    printf "\e[0m %d\n" "$total_severe_errors"

    printf "Mild Errors:    "
    printf "\e[91m"
    for ((i=0; i<normalized_mild_errors; i++)); do
        printf "▅"
    done
    printf "\e[0m %d\n" "$total_mild_errors"

    printf "Warnings:       "
    printf "\e[33m"
    for ((i=0; i<normalized_warnings; i++)); do
        printf "▅"
    done
    printf "\e[0m %d\n" "$total_warnings"

    printf "Others:         "
    printf "\e[32m"
    for ((i=0; i<normalized_success && i<100; i++)); do
        printf "▅"
    done
    printf "\e[0m %d\n" "$SUCCESS_COUNT"
}

main() {
    spin_loader $$ &
    spinner_pid=$!
    parse_log

    kill "$spinner_pid"
    wait "$spinner_pid"

    print_summary
    print_graph
    print_specific_error_table
}

main
