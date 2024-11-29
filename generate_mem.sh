#!/bin/bash

if [[ $# -lt 1 ]]; then
    echo "Usage: $0 YYYY-MM-DD [data_type]"
    echo "Example: $0 2024-11-09"
    echo "         $0 2024-11-09 system_metrics"
    exit 1
fi

INPUT_DATE=$1
DATA_TYPE=${2:-error_counts}
ERROR_COUNTS_FILE="data/error_counts.dat"
if [[ "$DATA_TYPE" == "error_counts" ]]; then
    DATA_FILE="$ERROR_COUNTS_FILE"
    OUTPUT_GRAPH="error_counts.png"
    TITLE="Error and Success Counts for $INPUT_DATE"

else
    echo "Error: Invalid data type specified. Use 'error_counts'."
    exit 1
fi

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
if [[ $? -eq 0 ]]; then
    echo "Generated graph: $GRAPH_DIR/$OUTPUT_GRAPH"
else
    echo "Error generating graph for $DATA_TYPE."
    exit 1
fi
