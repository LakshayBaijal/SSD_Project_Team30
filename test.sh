#!/bin/bash


declare -A SEVERE_ERROR_COUNT=(
    ["systemd"]=2
    ["kernel"]=2
    ["gnome-shell"]=3
    ["apache2"]=5
    ["myappsdadsauyf uvdsvdvdvdsvdsyg"]=0
)


if [[ ${#SEVERE_ERROR_COUNT[@]} -gt 0 ]]; then
    printf "\e[31msevere errors:\e[0m\n"
    echo
    printf "%-20s %-20s\n" "Application" "Severe Error Count"
    printf "%-20s %-20s\n" "------------" "------------------"
    
    for app in "${!SEVERE_ERROR_COUNT[@]}"; do
        printf "%-20s %-20d\n" "$app" "${SEVERE_ERROR_COUNT[$app]}"
    done
fi
