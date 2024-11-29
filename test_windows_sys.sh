#!/bin/bash

DATE=$1
START_TIME=$2
END_TIME=$3
LOG_FILE=$4

if [[ $4 != "nofile" ]]; then
    LOG_FILE=$4
fi

if [[ $DATE =~ ^[0-9]{4}-[0-9]{2}-[0-9]{2}$ ]]; then
    DATE=$(date -d "$DATE" +"%d-%m-%Y")
else
    echo "Invalid date format. Please provide the date in yyyy-mm-dd format."
    exit 1
fi

if [[ -z "$DATE" || -z "$START_TIME" || -z "$END_TIME" || -z "$LOG_FILE" ]]; then
    echo "Usage: $0 DATE START_TIME END_TIME LOG_FILE"
    echo "Example: $0 28-11-2024 00:00:00 23:00:00 Windows_System"
    exit 1
fi


if [[ ! -f "$LOG_FILE" ]]; then
    echo "Error: Log file not found: $LOG_FILE"
    exit 1
fi


declare -A SEVERE_ERROR_COUNT
declare -A MILD_ERROR_COUNT
declare -A WARNING_COUNT
SUCCESS_COUNT=0


TOTAL_SEVERE_ERRORS=0
TOTAL_MILD_ERRORS=0
TOTAL_WARNINGS=0


declare -A OOM_ERRORS
declare -A KERNEL_ERRORS
declare -A CRITICAL_ERRORS
declare -A DISK_IO_ERRORS


categorize_message() {
    local message="$1"
    local category="success"  # Default category if not error or warning

    if [[ $message =~ (kernel\ bug|OOM|out\ of\ memory|critical|disk\ failure|I/O\ error|Chkdsk) ]]; then
        category="severe_error"
    elif [[ $message =~ (error|fail|failed) ]]; then
        category="mild_error"
    elif [[ $message =~ (warning|deprecated|high\ usage|not\ recommended) ]]; then
        category="warning"
    fi

    printf "%s\n" "$category"
}


track_specific_errors() {
    local source="$1"
    local message="$2"


    if [[ $message =~ (OOM|out\ of\ memory) ]]; then
        OOM_ERRORS["$source"]=$((OOM_ERRORS["$source"] + 1))
    elif [[ $message =~ (kernel\ bug) ]]; then
        KERNEL_ERRORS["$source"]=$((KERNEL_ERRORS["$source"] + 1))
    elif [[ $message =~ (critical) ]]; then
        CRITICAL_ERRORS["$source"]=$((CRITICAL_ERRORS["$source"] + 1))
    elif [[ $message =~ (disk\ failure|I/O\ error|Chkdsk) ]]; then
        DISK_IO_ERRORS["$source"]=$((DISK_IO_ERRORS["$source"] + 1))
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

    read -r header < "$log_file"

    IFS=$'\t' read -r -a headers <<< "$header"
    for i in "${!headers[@]}"; do
        case "${headers[$i]}" in
            "Level") LEVEL_POS=$i ;;
            "Date and Time") DATETIME_POS=$i ;;
            "Source") SOURCE_POS=$i ;;
            "Event ID") EVENTID_POS=$i ;;
            "Task Category") TASKCAT_POS=$i ;;
        esac
    done

    while IFS=$'\t' read -r -a fields; do
        if [[ -z "${fields[*]}" ]]; then
            continue
        fi

        if [[ ${#fields[@]} -lt 5 ]]; then
            continue
        fi
        level="${fields[$LEVEL_POS]}"
        datetime="${fields[$DATETIME_POS]}"
        source="${fields[$SOURCE_POS]}"
        event_id="${fields[$EVENTID_POS]}"
        task_category="${fields[$TASKCAT_POS]}"

        message="${fields[@]:5}"


        IFS=' ' read -r log_date log_time <<< "$datetime"


        if [[ "$log_date" != "$DATE" ]]; then
            continue
        fi


        if [[ "$log_time" < "$START_TIME" || "$log_time" > "$END_TIME" ]]; then
            continue
        fi
        category=$(categorize_message "$message")

        track_specific_errors "$source" "$message"

        case $category in
            "severe_error")
                SEVERE_ERROR_COUNT["$source"]=$((SEVERE_ERROR_COUNT["$source"] + 1))
                TOTAL_SEVERE_ERRORS=$((TOTAL_SEVERE_ERRORS + 1))
                ;;
            "mild_error")
                MILD_ERROR_COUNT["$source"]=$((MILD_ERROR_COUNT["$source"] + 1))
                TOTAL_MILD_ERRORS=$((TOTAL_MILD_ERRORS + 1))
                ;;
            "warning")
                WARNING_COUNT["$source"]=$((WARNING_COUNT["$source"] + 1))
                TOTAL_WARNINGS=$((TOTAL_WARNINGS + 1))
                ;;
            "success")
                SUCCESS_COUNT=$((SUCCESS_COUNT + 1))
                ;;
        esac

    done < <(tail -n +2 "$log_file")
}
print_summary() {
    echo
    printf "\n\e[35mSummary of Errors and Warnings:\e[0m\n"
    echo

    if [[ ${#SEVERE_ERROR_COUNT[@]} -gt 0 ]]; then
        printf "\e[31mSevere Errors:\e[0m\n"
        echo
        printf "%-40s %-20s\n" "Source" "Severe Error Count"
        printf "%-40s %-20s\n" "------" "------------------"
        for source in "${!SEVERE_ERROR_COUNT[@]}"; do
            printf "%-40s %-20d\n" "$source" "${SEVERE_ERROR_COUNT[$source]}"
        done
        echo
    fi
    if [[ ${#MILD_ERROR_COUNT[@]} -gt 0 ]]; then
        printf "\e[91mMild Errors:\e[0m\n"
        echo
        printf "%-40s %-20s\n" "Source" "Mild Error Count"
        printf "%-40s %-20s\n" "------" "----------------"
        for source in "${!MILD_ERROR_COUNT[@]}"; do
            printf "%-40s %-20d\n" "$source" "${MILD_ERROR_COUNT[$source]}"
        done
        echo
    fi
    if [[ ${#WARNING_COUNT[@]} -gt 0 ]]; then
        printf "\e[33mWarnings:\e[0m\n"
        echo
        printf "%-40s %-20s\n" "Source" "Warning Count"
        printf "%-40s %-20s\n" "------" "-------------"
        for source in "${!WARNING_COUNT[@]}"; do
            printf "%-40s %-20d\n" "$source" "${WARNING_COUNT[$source]}"
        done
        echo
    fi
    echo -e "\e[32mSuccess count:\e[0m $SUCCESS_COUNT"
    echo -e "\e[32mTotal:\e[0m $((SUCCESS_COUNT + TOTAL_SEVERE_ERRORS + TOTAL_MILD_ERRORS + TOTAL_WARNINGS))"
    echo
}
print_specific_error_table() {
    printf "\n\e[35mError Table:\e[0m\n"
    echo
    printf "%-20s %-40s %-10s %-30s\n" "Error" "Source" "Count" "Error Message"


    for source in "${!OOM_ERRORS[@]}"; do
        printf "%-20s %-40s %-10d %-30s\n" "Out of Memory" "$source" "${OOM_ERRORS[$source]}" "Out of Memory"
    done

    for source in "${!KERNEL_ERRORS[@]}"; do
        printf "%-20s %-40s %-10d %-30s\n" "Kernel Bug" "$source" "${KERNEL_ERRORS[$source]}" "Kernel Bug"
    done

    for source in "${!CRITICAL_ERRORS[@]}"; do
        printf "%-20s %-40s %-10d %-30s\n" "Critical" "$source" "${CRITICAL_ERRORS[$source]}" "Critical Error"
    done

    for source in "${!DISK_IO_ERRORS[@]}"; do
        printf "%-20s %-40s %-10d %-30s\n" "Disk Failure" "$source" "${DISK_IO_ERRORS[$source]}" "Disk Failure / I/O Error"
    done


    if [[ ${#OOM_ERRORS[@]} -eq 0 ]]; then
        printf "%-20s %-40s %-10d %-30s\n" "Out of Memory" "N/A" "0" "Out of Memory"
    fi
    if [[ ${#KERNEL_ERRORS[@]} -eq 0 ]]; then
        printf "%-20s %-40s %-10d %-30s\n" "Kernel Bug" "N/A" "0" "Kernel Bug"
    fi
    if [[ ${#CRITICAL_ERRORS[@]} -eq 0 ]]; then
        printf "%-20s %-40s %-10d %-30s\n" "Critical" "N/A" "0" "Critical Error"
    fi
    if [[ ${#DISK_IO_ERRORS[@]} -eq 0 ]]; then
        printf "%-20s %-40s %-10d %-30s\n" "Disk Failure" "N/A" "0" "Disk Failure / I/O Error"
    fi
}

print_graph() {
    echo
    printf "\n\e[1;38;2;195;43;237mGraph:\n\e[0m"
    echo

    MAX_VALUE=$((TOTAL_SEVERE_ERRORS > TOTAL_MILD_ERRORS ? TOTAL_SEVERE_ERRORS : TOTAL_MILD_ERRORS))
    MAX_VALUE=$((MAX_VALUE > TOTAL_WARNINGS ? MAX_VALUE : TOTAL_WARNINGS))
    MAX_VALUE=$((MAX_VALUE > SUCCESS_COUNT ? MAX_VALUE : SUCCESS_COUNT))


    if [[ "$MAX_VALUE" -eq 0 ]]; then
        MAX_VALUE=1
    fi


    NORMALIZED_SEVERE_ERRORS=$((TOTAL_SEVERE_ERRORS * 50 / MAX_VALUE))
    NORMALIZED_MILD_ERRORS=$((TOTAL_MILD_ERRORS * 50 / MAX_VALUE))
    NORMALIZED_WARNINGS=$((TOTAL_WARNINGS * 50 / MAX_VALUE))
    NORMALIZED_SUCCESS=$((SUCCESS_COUNT * 50 / MAX_VALUE))
    printf "Severe Errors:  "
    for ((i=0; i<NORMALIZED_SEVERE_ERRORS; i++)); do
        printf "\e[31m▅\e[0m"
    done
    printf " %d\n" "$TOTAL_SEVERE_ERRORS"

    printf "Mild Errors:    "
    for ((i=0; i<NORMALIZED_MILD_ERRORS; i++)); do
        printf "\e[91m▅\e[0m"
    done
    printf " %d\n" "$TOTAL_MILD_ERRORS"

    printf "Warnings:       "
    for ((i=0; i<NORMALIZED_WARNINGS; i++)); do
        printf "\e[33m▅\e[0m"
    done
    printf " %d\n" "$TOTAL_WARNINGS"


    printf "Successes:      "
    for ((i=0; i<NORMALIZED_SUCCESS && i<100; i++)); do
        printf "\e[32m▅\e[0m"
        if [[ $i -ge 100 ]]; then
            break
        fi
    done
    printf " %d\n" "$SUCCESS_COUNT"
    echo
}

main() {
    spin_loader $$ &
    spinner_pid=$!
    parse_log

    kill "$spinner_pid"
    wait "$spinner_pid"


    print_summary
    print_specific_error_table
    print_graph
}

main
