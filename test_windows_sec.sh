#!/bin/bash

if [ $# -ne 4 ]; then
    echo "Usage: $0 <start_date> <start_time> <end_time> <log_file>"
    echo "Example: $0 28-11-2024 00:00:00 23:59:59 Windows_Security.log"
    exit 1
fi
start_date="$1"
start_time="$2"
end_time="$3"
input_file="$4"

if [[ $start_date =~ ^[0-9]{4}-[0-9]{2}-[0-9]{2}$ ]]; then
    start_date=$(date -d "$start_date" +"%d-%m-%Y")
else
    echo "Invalid date format. Please provide the date in yyyy-mm-dd format."
    exit 1
fi


if [ ! -f "$input_file" ]; then
    echo "Error: Log file not found!"
    exit 1
fi

awk -F '\t' -v start_date="$start_date" -v start_time="$start_time" -v end_time="$end_time" '{
    split($2, datetime, " ")
    log_date = datetime[1]
    log_time = datetime[2]
    
    if (log_date == start_date && log_time >= start_time && log_time <= end_time) {
        event_desc = $5
        user_activity[event_desc]++
    }
} END {
    # Print table header
    printf "| %-32s | %-11s |\n", "Action", "Occurrences"
    printf "|------------------------------------------------|\n"
    
    # Print each user activity
    for (desc in user_activity) {
        printf "| %-32s | %11d |\n", desc, user_activity[desc]
    }
}' "$input_file"

exit 0
