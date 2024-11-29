#!/bin/bash

INPUT_DATE=$1

if [[ -z "$INPUT_DATE" ]]; then
    echo "Usage: $0 <YYYY-MM-DD>"
    echo "Example: $0 2024-10-04"
    exit 1
fi

DATA_DIR="data/$INPUT_DATE"
GRAPH_DIR="graphs/$INPUT_DATE"
if [[ ! -d "$DATA_DIR" ]]; then
    echo "Error: Data directory '$DATA_DIR' does not exist. Run sys_stat.sh first."
    exit 1
fi

mkdir -p "$GRAPH_DIR"
if [[ -f "$DATA_DIR/memory_usage.dat" ]]; then
    memory_used=$(awk 'NR==2 {print $1}' "$DATA_DIR/memory_usage.dat")
    memory_total=$(awk 'NR==2 {print $2}' "$DATA_DIR/memory_usage.dat")
    memory_free=$(echo "$memory_total - $memory_used" | bc)
    echo -e "Memory\tValue\nUsed\t${memory_used}\nFree\t${memory_free}" > "$DATA_DIR/memory_usage_bar.dat"

    gnuplot <<-EOF
    set terminal png size 800,600
    set output '$GRAPH_DIR/memory_usage.png'
    set title 'Memory Usage on $INPUT_DATE'
    set datafile separator "\t"
    set style data histograms
    set style fill solid 1.00 border -1
    set ylabel 'Memory (MB)'
    set grid ytics
    plot '$DATA_DIR/memory_usage_bar.dat' using 2:xtic(1) title ''
EOF
    echo "Generated $GRAPH_DIR/memory_usage.png"
else
    echo "Data file $DATA_DIR/memory_usage.dat not found."
fi

if [[ -f "$DATA_DIR/disk_usage.dat" ]]; then
    disk_used=$(awk 'NR==2 {print $1}' "$DATA_DIR/disk_usage.dat")
    disk_free=$(echo "100 - $disk_used" | bc)
    echo -e "Disk\tValue\nUsed\t${disk_used}\nFree\t${disk_free}" > "$DATA_DIR/disk_usage_bar.dat"

    gnuplot <<-EOF
    set terminal png size 800,600
    set output '$GRAPH_DIR/disk_usage.png'
    set title 'Disk Usage on $INPUT_DATE'
    set datafile separator "\t"
    set style data histograms
    set style fill solid 1.00 border -1
    set ylabel 'Disk Usage (%)'
    set grid ytics
    plot '$DATA_DIR/disk_usage_bar.dat' using 2:xtic(1) title ''
EOF
    echo "Generated $GRAPH_DIR/disk_usage.png"
else
    echo "Data file $DATA_DIR/disk_usage.dat not found."
fi


if [[ -f "$DATA_DIR/paging_sar.dat" ]]; then

    grep -E '^[0-9]' "$DATA_DIR/paging_sar.dat" > "$DATA_DIR/paging_sar_data.dat"

    awk '{print $1, $2, $3}' "$DATA_DIR/paging_sar_data.dat" > "$DATA_DIR/paging_time_series.dat"

    gnuplot <<-EOF
    set terminal png size 1000,600
    set output '$GRAPH_DIR/paging_over_time.png'
    set title 'Paging Activity Over Time on $INPUT_DATE'
    set datafile separator whitespace
    set xdata time
    set timefmt "%H:%M:%S"
    set format x "%H:%M"
    set xlabel 'Time'
    set ylabel 'Pages per Second'
    set grid
    plot '$DATA_DIR/paging_time_series.dat' using 1:2 with lines title 'pgpgin/s', \
        '' using 1:3 with lines title 'pgpgout/s'
EOF
    echo "Generated $GRAPH_DIR/paging_over_time.png"
else
    echo "Data file $DATA_DIR/paging_sar.dat not found."
fi
echo "All graphs have been generated in the '$GRAPH_DIR' directory."