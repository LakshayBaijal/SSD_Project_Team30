#!/bin/bash

# ================================
# Script: sys_stat.sh
# Description: Collects system statistics, saves them into date-specific data files, and generates graphs.
# Usage: ./sys_stat.sh <YYYY-MM-DD> <START_TIME> <END_TIME>
# Example: ./sys_stat.sh 2024-10-04 00:00:00 23:59:59
# ================================

INPUT_DATE=$1  # Expected format: YYYY-MM-DD
START_TIME=$2  # Expected format: HH:MM:SS
END_TIME=$3    # Expected format: HH:MM:SS

if [[ -z "$INPUT_DATE" || -z "$START_TIME" || -z "$END_TIME" ]]; then
    echo "Usage: $0 <YYYY-MM-DD> <START_TIME> <END_TIME>"
    echo "Example: $0 2024-10-04 00:00:00 23:59:59"
    exit 1
fi

printf "\n"
memory_used=$(free -m | awk '/^Mem:/ {print $3}')
memory_total=$(free -m | awk '/^Mem:/ {print $2}')
memory_percentage=$(echo "scale=2; $memory_used * 100 / $memory_total" | bc)

if (( $(echo "$memory_percentage > 75" | bc -l) )); then
    echo -e "\e[31mMemory Usage: Used: ${memory_used}MB / Total: ${memory_total}MB (High)\e[0m"
elif (( $(echo "$memory_percentage > 50" | bc -l) )); then
    echo -e "\e[33mMemory Usage: Used: ${memory_used}MB / Total: ${memory_total}MB (Moderate)\e[0m"
else
    echo -e "\e[32mMemory Usage: Used: ${memory_used}MB / Total: ${memory_total}MB (Normal)\e[0m"
fi

disk_usage=$(df --output=pcent / | tail -1 | tr -dc '0-9')
if [[ -n "$disk_usage" && "$disk_usage" =~ ^[0-9]+$ ]]; then
    if (( disk_usage > 80 )); then
        echo -e "\e[31mDisk Usage: ${disk_usage}% (High)\e[0m"
    else
        echo -e "\e[32mDisk Usage: ${disk_usage}% (Normal)\e[0m"
    fi
else
    echo "Could not retrieve disk usage."
fi

swap_used=$(free -m | awk '/^Swap:/ {print $3}')
swap_total=$(free -m | awk '/^Swap:/ {print $2}')

if [[ "$swap_total" -eq 0 ]]; then
    swap_percentage=0
else
    swap_percentage=$(echo "scale=2; $swap_used * 100 / $swap_total" | bc)
fi

if (( $(echo "$swap_percentage > 75" | bc -l) )); then
    echo -e "\e[31mSwap Usage: Used: ${swap_used}MB / Total: ${swap_total}MB (High)\e[0m"
    echo -e "\e[35mHigh memory usage processes are:\e[0m"
    ps aux --sort=-%mem | awk 'NR<=11 {printf "%-10s %-5s %s\n", $1, $4"%", $11}'
else
    echo -e "\e[32mSwap Usage: Used: ${swap_used}MB / Total: ${swap_total}MB (Normal)\e[0m"
fi

printf "\n"
printf "Memory and paging details for interval\n"

CURRENT_DATE=$(date +%Y-%m-%d)
SEVEN_DAYS_AGO=$(date -d '7 days ago' +%Y-%m-%d)

if [[ "$INPUT_DATE" < "$SEVEN_DAYS_AGO" ]] || [[ "$INPUT_DATE" > "$CURRENT_DATE" ]]; then
    echo "Error: The entered date is outside the last 7 days."
    exit 1
fi

SYSSTAT_DIR="/var/log/sysstat"  # Adjust to the correct path for your system

DAY_NUMBER=$(date -d "$INPUT_DATE" +%d)
SYSSTAT_FILE="$SYSSTAT_DIR/sa$DAY_NUMBER"
echo "$SYSSTAT_FILE"
if [[ ! -f "$SYSSTAT_FILE" ]]; then
    echo "Error: Sysstat file for the entered date does not exist."
    exit 1
fi

START_TIMESTAMP="$INPUT_DATE $START_TIME"
END_TIMESTAMP="$INPUT_DATE $END_TIME"
echo "Displaying system stats for $START_TIMESTAMP to $END_TIMESTAMP"

# Run the sar command with the custom start and end times
sar -r -B -W -s "$START_TIME" -e "$END_TIME" -f "$SYSSTAT_FILE" -i 1800 --human --pretty

# ================================
# Added Code: Write Data to Date-Specific .dat Files
# ================================

# Create date-specific data directory if it doesn't exist
DATA_DIR="data/$INPUT_DATE"
mkdir -p "$DATA_DIR"

# Write memory usage data to data/<INPUT_DATE>/memory_usage.dat
echo -e "memory_used\tmemory_total\tmemory_percentage" > "$DATA_DIR/memory_usage.dat"
echo -e "${memory_used}\t${memory_total}\t${memory_percentage}" >> "$DATA_DIR/memory_usage.dat"

# Write disk usage data to data/<INPUT_DATE>/disk_usage.dat
echo -e "disk_usage" > "$DATA_DIR/disk_usage.dat"
echo -e "${disk_usage}" >> "$DATA_DIR/disk_usage.dat"

# Write swap usage data to data/<INPUT_DATE>/swap_usage.dat
echo -e "swap_used\tswap_total\tswap_percentage" > "$DATA_DIR/swap_usage.dat"
echo -e "${swap_used}\t${swap_total}\t${swap_percentage}" >> "$DATA_DIR/swap_usage.dat"

# Save sar command outputs to separate data files for graphing
sar -r -s "$START_TIME" -e "$END_TIME" -f "$SYSSTAT_FILE" > "$DATA_DIR/memory_sar.dat"
sar -B -s "$START_TIME" -e "$END_TIME" -f "$SYSSTAT_FILE" > "$DATA_DIR/paging_sar.dat"
sar -W -s "$START_TIME" -e "$END_TIME" -f "$SYSSTAT_FILE" > "$DATA_DIR/swapping_sar.dat"

# Save high memory usage processes if swap usage is high
if (( $(echo "$swap_percentage > 75" | bc -l) )); then
    ps aux --sort=-%mem | awk 'NR<=11 {printf "%s\t%s\t%s\n", $1, $4, $11}' > "$DATA_DIR/high_memory_processes.dat"
fi

echo "Data files generated in the '$DATA_DIR' directory."

# ================================
# Call generate_sys_stat.sh Automatically
# ================================

# Check if generate_sys_stat.sh exists and is executable
if [[ -x "./generate_sys_stat.sh" ]]; then
    echo "Generating graphs using generate_sys_stat.sh..."
    ./generate_sys_stat.sh "$INPUT_DATE"
else
    echo "Error: generate_sys_stat.sh not found or not executable."
    exit 1
fi
