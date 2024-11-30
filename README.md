# Log Analysis System with Shell Scripting

https://github.com/user-attachments/assets/ed7f74a3-f6cc-43ee-94dc-d33623ab2287

## Objective and Implementation

Developed a robust Bash-based log parsing and visualization tool designed to analyze system log files, categorize various error types, track specific error occurrences per application, and generate comprehensive summaries along with visual graphs for enhanced system monitoring and troubleshooting.

## Log File Parsing:

Flexible Input Handling: Supports parsing of default system logs (e.g., /var/log/syslog) and custom log files provided via command-line arguments.
Date and Time Filtering: Enables filtering of log entries based on specific dates and time ranges to focus on relevant data subsets.
Error Categorization:

Dynamic Classification: Utilizes regular expressions to categorize log messages into Severe Errors, Mild Errors, Warnings, and Successes.
Specific Error Tracking: Maintains detailed counts for critical error types such as Out of Memory (OOM) errors, segmentation faults, memory allocation failures, kernel bugs, and disk I/O issues on a per-application basis.

## Data Aggregation and Summarization:

Associative Arrays: Implements Bash associative arrays to efficiently store and count occurrences of different error categories and specific error types.
Comprehensive Summaries: Generates summarized reports detailing the number of severe errors, mild errors, warnings, and successful operations, providing a clear overview of system health.

## Visual Reporting:

Graph Generation with Gnuplot: Integrates Gnuplot to create visually appealing PNG graphs representing error and success counts, facilitating easy interpretation of log data.
Color-Coded Outputs: Enhances readability by applying ANSI color codes to terminal outputs, distinguishing between different error categories and highlighting key information.
Spinner Animation: Incorporates a spinner animation to indicate processing activity, improving user experience during long-running operations.

## Data Export and Integration:

Structured Data Output: Exports error counts to a file error_counts.dat for potential integration with other monitoring tools or further data analysis.
Modular Design: Facilitates extensibility by allowing the addition of more data types and integration with auxiliary scripts (e.g., generate_mem.sh) for extended functionality.

## How to Run

1. Give executable permissions to every script by running the following command:  
   ```bash
   chmod +x <script_name>
   ```

2. Run the log analysis through `driver.sh`:  
   ```bash
   ./driver.sh
   ```

3. To debug and run a specific script, use the following structure:  
   ```bash
   sudo ./test_auth.sh <date: yyyy-mm-dd> <start_time: hh:mm:ss> <end_time: hh:mm:ss>
   ```
   - **Custom Debug Scripts :** Replace test_auth.sh to desired  script.
