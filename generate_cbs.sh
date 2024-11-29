#!/bin/bash

if ! command -v gnuplot &> /dev/null; then
    echo "Error: 'gnuplot' command not found. Please install gnuplot to generate graphs."
    exit 1
fi
INPUT_DATE=$1

if [[ -z "$INPUT_DATE" ]]; then
    INPUT_DATE=$(date +"%Y-%m-%d")
fi

DATA_DIR="data"
GRAPH_DIR="graphs/$INPUT_DATE"

mkdir -p "$GRAPH_DIR"

if [[ -f "$DATA_DIR/error_counts.dat" ]]; then
    gnuplot <<-EOF
        set terminal png size 800,600
        set output "$GRAPH_DIR/error_counts.png"
        set title "Error Counts on $INPUT_DATE"
        set style data histograms
        set style histogram cluster gap 1
        set style fill solid border -1
        set boxwidth 0.9
        set grid ytics
        set ylabel "Count"
        set xlabel "Error Categories"
        set xtics rotate by -45
        set key off
        plot "$DATA_DIR/error_counts.dat" using 2:xtic(1) linecolor rgb "#406090"
EOF
    echo "Generated graph: $GRAPH_DIR/error_counts.png"
else
    echo "Warning: '$DATA_DIR/error_counts.dat' not found. Skipping error counts graph."
fi

if [[ -f "$DATA_DIR/system_metrics.dat" ]]; then
    grep -E "Memory Usage|Disk Usage|Swap Usage" "$DATA_DIR/system_metrics.dat" > "$DATA_DIR/system_metrics_plot.dat"
    gnuplot <<-EOF
        set terminal png size 800,600
        set output "$GRAPH_DIR/system_metrics.png"
        set title "System Metrics on $INPUT_DATE"
        set style data histograms
        set style histogram cluster gap 1
        set style fill solid border -1
        set boxwidth 0.9
        set grid ytics
        set ylabel "Percentage (%)"
        set xlabel "Metrics"
        set xtics rotate by -45
        set key off
        plot "$DATA_DIR/system_metrics_plot.dat" using 2:xtic(1) linecolor rgb "#40A090"
EOF
    echo "Generated graph: $GRAPH_DIR/system_metrics.png"
    rm "$DATA_DIR/system_metrics_plot.dat"
else
    echo "Warning: '$DATA_DIR/system_metrics.dat' not found. Skipping system metrics graph."
fi
