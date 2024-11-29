#!/bin/bash
if [[ $# -lt 1 ]]; then
    echo "Usage: $0 YYYY-MM-DD"
    echo "Example: $0 2024-11-09"
    exit 1
fi

INPUT_DATE=$1

DATA_FILE="data/auth_events.dat"
OUTPUT_GRAPH="auth_events.png"
TITLE="Authentication Events for $INPUT_DATE"

if [[ ! -f "$DATA_FILE" ]]; then
    echo "Error: Data file '$DATA_FILE' not found."
    exit 1
fi
BASE_DIR="graphs"

GRAPH_DIR="$BASE_DIR/$INPUT_DATE"

mkdir -p "$GRAPH_DIR"
if ! command -v gnuplot &> /dev/null; then
    echo "Error: Gnuplot is not installed. Please install it to generate graphs."
    exit 1
fi

gnuplot <<- EOF
    set datafile separator "\t"
    set terminal png size 800,600 enhanced font 'Verdana,12'
    set output "$GRAPH_DIR/$OUTPUT_GRAPH"
    set title "$TITLE"
    set xlabel "Event Categories"
    set ylabel "Count"
    set grid ytics
    set style fill solid 1.0 border -1
    set style data boxes
    set boxwidth 0.5
    set key off
    set yrange [0:*]
    set xtics rotate by -45

    # Skip the header line
    set key off

    # Plot the data file with count/value labels on top of each bar
    plot "$DATA_FILE" using 2:xtic(1) with boxes notitle, \
        "" using 0:2:2 with labels center offset 0,1 notitle
EOF

if [[ $? -eq 0 ]]; then
    echo "Generated graph: $GRAPH_DIR/$OUTPUT_GRAPH"
else
    echo "Error generating graph for authentication events."
    exit 1
fi
