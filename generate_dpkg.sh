#!/bin/bash

# ================================
# Script: generate_dpkg.sh
# Description: Generates a bar graph for dpkg package actions using Gnuplot.
# Usage: ./generate_dpkg.sh <YYYY-MM-DD>
# Example: ./generate_dpkg.sh 2024-10-04
# ================================

# Check if Gnuplot is installed
if ! command -v gnuplot &> /dev/null; then
    echo "Error: Gnuplot is not installed. Please install Gnuplot to generate graphs."
    exit 1
fi

# Check if at least one argument is provided
if [[ $# -lt 1 ]]; then
    echo "Usage: $0 <YYYY-MM-DD>"
    echo "Example: $0 2024-10-04"
    exit 1
fi

INPUT_DATE=$1

# Define data file path
DATA_FILE="data/dpkg_actions.dat"

# Define graph output settings
OUTPUT_GRAPH="dpkg_actions.png"
TITLE="dpkg Package Actions for $INPUT_DATE"

# Check if data file exists
if [[ ! -f "$DATA_FILE" ]]; then
    echo "Error: Data file '$DATA_FILE' not found."
    exit 1
fi

# Define graph directory
GRAPH_DIR="graphs/$INPUT_DATE"

# Create graph directory if it doesn't exist
mkdir -p "$GRAPH_DIR"

# Check if there's at least one non-zero count
total_count=$(awk 'NR>1 {sum += $2} END {print sum}' "$DATA_FILE")
if [[ "$total_count" -eq 0 ]]; then
    echo "No data to plot for dpkg actions."
    exit 0
fi

# Generate the bar graph using Gnuplot
gnuplot <<- EOF
    set datafile separator "\t"
    set terminal png size 1000,600 enhanced font 'Verdana,12'
    set output "$GRAPH_DIR/$OUTPUT_GRAPH"
    set title "$TITLE"
    set xlabel "Category"
    set ylabel "Value"
    set grid ytics
    set style fill solid 1.0 border -1
    set style data boxes
    set boxwidth 0.5
    set key off
    set yrange [0:*]
    set xtics rotate by -45

    # Plot the data file with count/value labels on top of each bar
    plot "$DATA_FILE" using 2:xtic(1) with boxes notitle, \
         "" using 0:2:2 with labels offset 0,1 notitle
EOF


# Check if Gnuplot succeeded
if [[ $? -eq 0 ]]; then
    echo "Generated graph: $GRAPH_DIR/$OUTPUT_GRAPH"
else
    echo "Error generating graph for dpkg actions."
    exit 1
fi
