#!/bin/bash

LOG_FILE="/var/log/syslog"  

#INPUT_DATE=$1  
# Parse the start and end dates from command line arguments
START_DATE=$1
END_DATE=$2
START_TIME=$3
END_TIME=$4

if [[ $5 != "nofile" ]]; then
    LOG_FILE=$5
fi
# if [[ ! -f "$LOG_FILE" ]]; then
#     echo "Error: Log file not found: $LOG_FILE"
#     exit 1
# fi

# Initialize counters and associative arrays
declare -A SEVERE_ERROR_COUNT
declare -A MILD_ERROR_COUNT
declare -A WARNING_COUNT
SUCCESS_COUNT=0  # This will count process-related logs only



declare -A OUT_OF_MEMORY_ERRORS
declare -A OOM_ERRORS
declare -A SEGFAULT_ERRORS
declare -A MALLOC_ERRORS
declare -A KERNEL_ERRORS
declare -A CRITICAL_ERRORS
declare -A DISK_IO_ERRORS



# Associative arrays to store specific process-related errors
declare -A PROCESS_CRASH_ERRORS
declare -A PROCESS_HANG_ERRORS
declare -A PROCESS_KILLED_ERRORS

# Associative arrays to store processor and GPU-related errors
declare -A CPU_ERRORS
declare -A GPU_ERRORS


declare -A ERROR_FULL_FORMS=(
    ["CBS"]="Component-Based Servicing"
    ["CSI"]="Component Servicing Infrastructure"
    ["WU"]="Windows Update"
    ["SFC"]="System File Checker"
    ["DISM"]="Deployment Imaging Service and Management Tool"
    ["BITS"]="Background Intelligent Transfer Service"
    ["KDC"]="Key Distribution Center"
    ["BFE"]="Base Filtering Engine"
    ["WUDF"]="Windows User-Mode Driver Framework"
    ["SPP"]="Software Protection Platform"
)

categorize_message() {
    local message="$1"
    local category="success"
    if [[ $message =~ (kernel\ bug|process\ crash|process\ hang|process\ killed|CPU\ fault|GPU\ failure|critical|OOM|out\ of\ memory|critical|disk\ failure|I/O\ error) ]]; then
        category="severe_error"
    elif [[ $message =~ (error|fail|failed|CPU\ warning|GPU\ warning|process\ issue|Failed) ]]; then
        category="mild_error"
    elif [[ $message =~ (Warning|warning|deprecated|high\ usage|not\ recommended) ]]; then
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

    # Check and store GPU-related specific errors
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

# spin_loader() {
#     local pid=$1
#     local spin=('|' '/' '-' '\')
#     local i=0

#     while kill -0 "$pid" 2>/dev/null; do
#         printf "\rProcessing log file... ${spin[i]} "
#         ((i=(i+1)%4))
#         sleep 0.1
#     done
#     printf "\rProcessing complete.           \n"  # Clean up the line
# }
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


# Function to parse the log file and extract app name and categorize the message
parse_log() {
    
    local log_file="$LOG_FILE"
    local date_format=1  # Use 1 for yyyy-mm-dd hh:mm:ss format
    local sample_line
    local timestamp
    local app_name
    local message
    local log_date
    local category

    # Convert START_DATE and END_DATE to the correct format for comparison
    # Combine START_DATE and START_TIME into a single string and format
    START_DATETIME="$START_DATE $START_TIME"
    START_DATE_FORMATTED=$(date -d "$START_DATETIME" +"%Y-%m-%d %H:%M:%S")

    # Combine END_DATE and END_TIME into a single string and format
    END_DATETIME="$END_DATE $END_TIME"
    END_DATE_FORMATTED=$(date -d "$END_DATETIME" +"%Y-%m-%d %H:%M:%S")


    while IFS= read -r line; do
        # Initialize the fields
        app_name=""
        message=""
        log_date=""

        # Debugging: Show the line being processed
        # echo "Processing line: $line"

        # Adjusted regex for timestamp including the comma at the end
        if [[ $line =~ ^([0-9]{4}-[0-9]{2}-[0-9]{2}) ]]; then
            # echo "$line"
            log_date=$(echo "$line" | cut -d',' -f1)

            # Remove the trailing comma if it exists (in case there is one)
            log_date="${log_date%,}"

            # Debugging: Check if the regex matched
            # echo "Matched timestamp: $log_date"

            # If log_date is greater than the end date, stop processing
            if [[ "$log_date" > "$END_DATE_FORMATTED" ]]; then
                # echo "Log date is greater than end date ($log_date > $END_DATE_FORMATTED). Breaking out of the loop."
                break
            fi
            # echo "$START_DATE_FORMATTED $log_date "

            # If log_date is within the range, process it
            # if [[ "$log_date" > "$START_DATE_FORMATTED" || "$log_date" == "$START_DATE_FORMATTED" ]] && [[ "$log_date" < "$END_DATE_FORMATTED" || "$log_date" == "$END_DATE_FORMATTED" ]]; then
            if [[ "$log_date" > "$START_DATE_FORMATTED" || "$log_date" == "$START_DATE_FORMATTED" ]]; then
                
                timestamp=$(echo "$line" | awk '{print $1 " " $2}')  # Capture the full timestamp
                # echo "Timestamp: $timestamp"
                # echo "insode"

                # Check if timestamp is within the specified range
                # if [[ "$timestamp" > "$START_DATE_FORMATTED" ]] && [[ "$timestamp" < "$END_DATE_FORMATTED" ]]; then
                    # Extract the app name and message
                    app_name=$(echo "$line" | awk '{print $4}' | cut -d '[' -f 1)  # App name is in the 4th column
                    message=$(echo "$line" | cut -d ',' -f 2- | sed 's/^ *//')  # Extract message after the timestamp
                    # echo "Extracted app name: $app_name"
                    # echo "Extracted message: $message"

                    file_path=$(echo "$line" | sed -n "s/.*path: \[\l:[0-9]*\]'\(.*\)' pid.*/\1/p")
                    # Extract PID
                    pid=$(echo "$line" | sed -n "s/.*pid: \([a-z0-9]*\).*/\1/p")

                    # echo "$line"
                    # Output the extracted information
                    # echo "Date and Time: $log_date"
                    # echo "File Path: $file_path"
                    # echo "PID: $pid"
                # fi
            fi
        # else
        #     # Debugging: If the regex doesn't match, print a message
        #     echo "Regex didn't match the line: $line"
        
        fi

        # If we have a message, process it
        if [[ -n "$message" ]]; then
            # Categorize the message
            # echo "$message"
            category=$(categorize_message "$message")

            # Track specific errors (process, processor, GPU)
            track_specific_errors "$app_name" "$message"

            # Increment counts based on the category, initialize if not already
            case $category in
                "severe_error")
                    SEVERE_ERROR_COUNT["$app_name"]=$((SEVERE_ERROR_COUNT["$app_name"]+1))
                    
                    ;;
                "mild_error")
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
    sleep 5 
}

# Function to print specific error table


# Function to print error and warning counts
print_summary() {
    printf "\n\e[34mSummary of Errors and Warnings:\e[0m\n"

    # Print severe errors
    # Print severe errors in a structured table
    # if [[ ${#SEVERE_ERROR_COUNT[@]} -gt 0 ]]; then
    #     printf "\n\e[31m%-20s %-15s %-20s\e[0m\n" "Error Type" "Service Name" "Count"
    #     printf "%-20s %-15s %-20s\n" "-------------------" "---------------" "-----"
    #     for entry in $(for app in "${!SEVERE_ERROR_COUNT[@]}"; do
    #                         echo "$app:${SEVERE_ERROR_COUNT[$app]}"
    #                     done | sort -t: -k2 -nr); do
    #         IFS=: read -r app count <<< "$entry"
    #         printf "%-20s %-15s %-20d\n" "Severe Error" "$app" "$count"
    #     done
    # fi

    # # Print mild errors in a structured table
    # if [[ ${#MILD_ERROR_COUNT[@]} -gt 0 ]]; then
    #     printf "\n\e[91m%-20s %-15s %-20s\e[0m\n" "Error Type" "Service Name" "Count"
    #     printf "%-20s %-15s %-20s\n" "-------------------" "---------------" "-----"
    #     for entry in $(for app in "${!MILD_ERROR_COUNT[@]}"; do
    #                         echo "$app:${MILD_ERROR_COUNT[$app]}"
    #                     done | sort -t: -k2 -nr); do
    #         IFS=: read -r app count <<< "$entry"
    #         printf "%-20s %-15s %-20d\n" "Mild Error" "$app" "$count"
    #     done
    # fi

    # # Print warnings in a structured table
    # if [[ ${#WARNING_COUNT[@]} -gt 0 ]]; then
    #     printf "\n\e[33m%-20s %-15s %-20s\e[0m\n" "Error Type" "Service Name" "Count"
    #     printf "%-20s %-15s %-20s\n" "-------------------" "---------------" "-----"
    #     for entry in $(for app in "${!WARNING_COUNT[@]}"; do
    #                         echo "$app:${WARNING_COUNT[$app]}"
    #                     done | sort -t: -k2 -nr); do
    #         IFS=: read -r app count <<< "$entry"
    #         printf "%-20s %-15s %-20d\n" "Warning" "$app" "$count"
    #     done
    # fi




    if [[ ${#SEVERE_ERROR_COUNT[@]} -gt 0 ]]; then
        printf "\n\e[31m%-20s %-15s %-30s %-20s\e[0m\n" "Error Type" "Service Name" "Description" "Count"
        printf "%-20s %-15s %-30s %-20s\n" "-------------------" "---------------" "------------------------------" "-----"
        for entry in $(for app in "${!SEVERE_ERROR_COUNT[@]}"; do
                            echo "$app:${SEVERE_ERROR_COUNT[$app]}"
                        done | sort -t: -k2 -nr); do
            IFS=: read -r app count <<< "$entry"
            full_form="${ERROR_FULL_FORMS[$app]:-"Unknown"}"  # If no full form is found, default to "Unknown"
            printf "%-20s %-15s %-30s %-20d\n" "Severe Error" "$app" "$full_form" "$count"
        done
    fi

    # Print mild errors with the new column order
    if [[ ${#MILD_ERROR_COUNT[@]} -gt 0 ]]; then
        printf "\n\e[91m%-20s %-15s %-30s %-20s\e[0m\n" "Error Type" "Service Name" "Description" "Count"
        printf "%-20s %-15s %-30s %-20s\n" "-------------------" "---------------" "------------------------------" "-----"
        for entry in $(for app in "${!MILD_ERROR_COUNT[@]}"; do
                            echo "$app:${MILD_ERROR_COUNT[$app]}"
                        done | sort -t: -k2 -nr); do
            IFS=: read -r app count <<< "$entry"
            full_form="${ERROR_FULL_FORMS[$app]:-"Unknown"}"
            printf "%-20s %-15s %-30s %-20d\n" "Mild Error" "$app" "$full_form" "$count"
        done
    fi

    # Print warnings with the new column order
    if [[ ${#WARNING_COUNT[@]} -gt 0 ]]; then
        printf "\n\e[33m%-20s %-15s %-30s %-20s\e[0m\n" "Error Type" "Service Name" "Description" "Count"
        printf "%-20s %-15s %-30s %-20s\n" "-------------------" "---------------" "------------------------------" "-----"
        for entry in $(for app in "${!WARNING_COUNT[@]}"; do
                            echo "$app:${WARNING_COUNT[$app]}"
                        done | sort -t: -k2 -nr); do
            IFS=: read -r app count <<< "$entry"
            full_form="${ERROR_FULL_FORMS[$app]:-"Unknown"}"
            printf "%-20s %-15s %-30s %-20d\n" "Warning" "$app" "$full_form" "$count"
        done
    fi



    # Print success count (process-related logs only)
    # Print success count (process-related logs only)
    # printf "\e[32mProcess-related Success Count:\e[0m %d\n" "$SUCCESS_COUNT"

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
    # Debug: Print the values before the check
    echo -e "\n\n\e[1;34mDebug Info:\e[0m"  # Blue for Debug Info title
    echo -e "\e[31mTotal Severe Errors:\e[0m $total_severe_errors"  # Red for Severe Errors
    echo -e "\e[33mTotal Mild Errors:\e[0m $total_mild_errors"  # Yellow for Mild Errors
    echo -e "\e[33mTotal Warnings:\e[0m $total_warnings"
    printf "\e[32msuccess count:\e[0m %d\n" $(( SUCCESS_COUNT - ${total_severe_errors} - ${total_mild_errors} - ${total_warnings} ))


    printf "\e[32mTotal:\e[0m%d" "$SUCCESS_COUNT"
    printf "\n"

    # Ensure the counts are integers
    if [[ -z "$total_severe_errors" || ! "$total_severe_errors" =~ ^[0-9]+$ ]] || \
        [[ -z "$total_mild_errors" || ! "$total_mild_errors" =~ ^[0-9]+$ ]] || \
        [[ -z "$total_warnings" || ! "$total_warnings" =~ ^[0-9]+$ ]] || \
        [[ -z "$SUCCESS_COUNT" || ! "$SUCCESS_COUNT" =~ ^[0-9]+$ ]]; then
        echo "Error: Counts is not valid integers."
        exit 1
    fi
    SUCCESS_COUNT=$(( SUCCESS_COUNT - ${total_severe_errors} - ${total_mild_errors} - ${total_warnings} ))
    # Find the maximum value among the counts for process-related logs
    # max_value=$(echo "$total_severe_errors $total_mild_errors $total_warnings $SUCCESS_COUNT" | awk '{
    #     max=$1; 
    #     for (i=2; i<=NF; i++) if ($i > max) max=$i; 
    #     print max
    # }')
    max_value=$(echo "$total_severe_errors" "$total_mild_errors" "$total_warnings" "$SUCCESS_COUNT" | awk '{print ($1>$2 && $1>$3 && $1>$4)?$1:($2>$3 && $2>$4)?$2:($3>$4)?$3:$4}')

    # Check if max_value is not zero to avoid division by zero errors
    if [[ $max_value -eq 0 ]]; then
        echo "No data to display."
        exit 1
    fi

    # Normalize the counts for process-related logs
    # Normalize the counts for process-related logs
    normalized_severe_errors=$(echo "scale=2; ($total_severe_errors / $max_value) * 120" | bc)
    normalized_mild_errors=$(echo "scale=2; ($total_mild_errors / $max_value) * 120" | bc)
    normalized_warnings=$(echo "scale=2; ($total_warnings / $max_value) * 120" | bc)
    normalized_success=$(echo "scale=2; ($SUCCESS_COUNT / $max_value) * 120" | bc)

    # Adjust normalized values: if value is between 0 and 1, set it to 1
    normalized_severe_errors=$(echo "$normalized_severe_errors" | awk '{if ($1 < 1) print 1; else print $1}')
    normalized_mild_errors=$(echo "$normalized_mild_errors" | awk '{if ($1 < 1) print 1; else print $1}')
    normalized_warnings=$(echo "$normalized_warnings" | awk '{if ($1 < 1) print 1; else print $1}')
    normalized_success=$(echo "$normalized_success" | awk '{if ($1 < 1) print 1; else print $1}')




    # Print horizontal graph for process-related logs
    printf "\nProcess-Related Log Graph:\n"

    # Total severe errors
    printf "Severe Errors:  "
    for ((i=0; i<${normalized_severe_errors%.*}; i++)); do
        printf "\e[31m▅\e[0m"
    done
    printf " $total_severe_errors\n"

    # Total mild errors
    printf "Mild Errors:    "
    for ((i=0; i<${normalized_mild_errors%.*}; i++)); do
        printf "\e[91m▅\e[0m"
    done
    printf " $total_mild_errors\n"


    # Total warnings
    printf "Warnings:       "
    for ((i=0; i<${normalized_warnings%.*}; i++)); do
        printf "\e[33m▅\e[0m"
    done
    printf " $total_warnings\n"

    # Success count
    printf "Total Success:  "
    for ((i=0; i<${normalized_success%.*}; i++)); do
        printf "\e[32m▅\e[0m"
    done
    printf " $SUCCESS_COUNT\n"

    # Print the specific error table
    # print_specific_error_table
    printf "\n\n"

}


# Main function
main() {
    if [[ -f $LOG_FILE ]]; then

        spin_loader $$ &
        spinner_pid=$!
        parse_log
        print_summary
        kill "$spinner_pid"
        wait "$spinner_pid" 



        line_count=$(wc -l < "$LOG_FILE")
        printf "\n\e[35mTotal log entries in file %s: \e[33m%d\e[0m\n\n\n" "$LOG_FILE" "$line_count"
    else
        printf "Error: Log file %s not found\n" "$LOG_FILE" >&2
        return 1
    fi
}

main "$@"