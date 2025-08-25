#!/bin/bash

GREEN="\e[32m"
RED="\e[31m"
NC="\e[0m"

spinner() {
    local pid=$1
    local message=$2
    local delay=0.1
    local spin='|/-\'
    local i=0

    while kill -0 "$pid" 2>/dev/null; do
        printf "\r%s %c" "$message" "${spin:i++%${#spin}:1}"
        sleep $delay
    done
}

run_step() {
    local message="$1"
    shift

    ("$@" >/dev/null 2>&1) &
    local pid=$!

    spinner $pid "$message"
    wait $pid
    local status=$?

    # Clear spinner line completely
    printf "\r\033[K"

    if [ $status -eq 0 ]; then
        printf "%s ... ${GREEN}OK${NC}\n" "$message"
    else
        printf "%s ... ${RED}FAILED${NC}\n" "$message"
        return 1
    fi
}
