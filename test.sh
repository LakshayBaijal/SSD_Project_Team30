#!/bin/bash
#  line="2024-10-20T05:01:57.469350+05:30 aryanprajapati-Dell-G15-5520 systemd[1]: logrotate.service: Deactivated successfully."
# INPUT_DATE="2024-10-20" 

# START_TIME="05:01:59"
# END_TIME="05:01:60"
# timestamp=$(echo "$line" | awk -F'T' '{print $2}' | cut -d '.' -f 1)

# if [[ "$timestamp" > "$START_TIME" || "$timestamp" == "$START_TIME" ]] && [[ "$timestamp" < "$END_TIME" || "$timestamp" == "$END_TIME" ]]; then
#   echo "Read"
# else 
# echo "fase"
# fi


#             echo "Timestamp: $timestamp"
#   if [[ $line =~ ([0-9]{4})-([0-9]{2})-([0-9]{2}) ]]; then
              
#                log_date="${BASH_REMATCH[0]}"
            
#                if [[ "$log_date" == "$INPUT_DATE" ]]; then
           
           
#                 timestamp=$(echo "$line" | awk '{print $1}')
#                 hostname=$(echo "$line" | awk '{print $2}')
              
#                 app_name=$(echo "$line" | awk '{print $3}' | cut -d '[' -f 1)  # Extract app name without PID
#                 message=$(echo "$line" | sed -n 's/.*]: //p' | sed -e 's/^ *//; s/ *$//')



#             echo "Timestamp: $timestamp"
#             echo "Hostname: $hostname"
#             echo "App Name: $app_name"
#             echo "Message: $message"

#             fi
#         fi

LOG_FILE="/var/log/syslog"

 log_file="$LOG_FILE"
c=0
tac "$log_file" | while IFS= read -r line; do
   echo "$line"
   (( c=c+1 ))
   if [ $c -eq 10 ]; then   # Corrected spacing and removed unnecessary brackets
       break
   fi                     # Added closing 'fi' for the 'if' statement
done