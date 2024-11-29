#!/bin/bash


log_file="solaris_log.txt"
severities=("warning" "error" "critical" "fatal")
messages=("Disk usage warning" "Memory error detected" "Critical disk failure" "Fatal kernel panic" "Service failure" "CPU overheating" "I/O error detected" "Process crash" "Disk corruption detected" "Authentication failure" "Login failure" "Disk space running low" "Network unreachable" "Service timeout")

success_messages=("System initialized successfully" "Disk usage is normal" "Kernel boot successful" "Memory allocated successfully" "Process started without errors" "Service apache2 started" "Authentication successful for user root" "I/O operation completed successfully" "Disk space is sufficient" "Service nginx started" "Filesystem mounted successfully" "System running optimally" "Network connection established" "File transfer successful" "Reboot completed successfully" "Login successful for user admin" "Configuration applied successfully" "Backup completed without errors" "Security audit passed successfully" "Network interface up" "No issues detected" "Software update applied successfully" "Application started without issues" "Disk health check passed")

num_lines=500
success_lines=415


for i in $(seq 1 $success_lines); do

    message=${success_messages[$RANDOM % ${#success_messages[@]}]}

    timestamp=$(date "+%b %d %H:%M:%S")

    log_entry="$timestamp solaris-host genunix: [ID $((RANDOM % 1000)) kern.success] $message"

    echo "$log_entry" >> "$log_file"
done


for i in $(seq $((success_lines + 1)) $num_lines); do
    severity=${severities[$RANDOM % ${#severities[@]}]}
    message=${messages[$RANDOM % ${#messages[@]}]}

    timestamp=$(date "+%b %d %H:%M:%S")

    log_entry="$timestamp solaris-host genunix: [ID $((RANDOM % 1000)) kern.$severity] $message
    echo "$log_entry" >> "$log_file"
done

echo "Synthetic Solaris log file with $num_lines entries generated in '$log_file'."
