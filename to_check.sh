#!/bin/bash

# Example log line from Windows event log
log_line="2016-09-28 04:30:31, Info                  CBS    SQM: Failed to start upload with file pattern: C:\Windows\servicing\sqm\*_std.sqm, flags: 0x2 [HRESULT = 0x80004005 - E_FAIL]"

# Debugging: Show the log line clearly
# echo "Original log line: '$log_line'"

# Remove carriage returns (if present)
log_line=$(echo "$log_line" | sed 's/\r//')

# Check the first part of the log line (before comma)
timestamp=$(echo "$log_line" | cut -d',' -f1)

echo "Extracted timestamp: '$timestamp'"

# Test the regex for matching the timestamp (accounting for the comma after the timestamp)
if [[ "$timestamp" =~ ^([0-9]{4}-[0-9]{2}-[0-9]{2}\s[0-9]{2}:[0-9]{2}:[0-9]{2}) ]]; then
    log_date="${BASH_REMATCH[1]}"
    echo "Matched timestamp: $log_date"
else
    echo "Regex didn't match."
fi

