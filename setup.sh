#!/bin/bash

set -euo pipefail

USERNAME="avan"
SSH_DIR="/home/$USERNAME/.ssh"
KEYS_URL="https://github.com/avanavan.keys"

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
        exit 1
    fi
}

if [ "$EUID" -ne 0 ]; then
    echo "Please run as root"
    exit 1
fi

if id "$USERNAME" &>/dev/null; then
    printf "Creating user: %s ... ${RED}FAILED (already exists)${NC}\n" "$USERNAME"
    exit 1
else
    run_step "Creating user: $USERNAME" useradd -m -s /bin/bash "$USERNAME"
fi

run_step "Adding $USERNAME to sudo group" usermod -aG sudo "$USERNAME"

echo "$USERNAME ALL=(ALL) NOPASSWD: ALL" > "/etc/sudoers.d/$USERNAME"
chmod 440 "/etc/sudoers.d/$USERNAME"
printf "Granting passwordless sudo ... ${GREEN}OK${NC}\n"

mkdir -p "$SSH_DIR"
rm -f "$SSH_DIR"/*
run_step "Fetching SSH keys for $USERNAME" wget -q -O "$SSH_DIR/authorized_keys" "$KEYS_URL"
chown -R "$USERNAME:$USERNAME" "$SSH_DIR"
chmod 700 "$SSH_DIR"
chmod 600 "$SSH_DIR/authorized_keys"
printf "Setting SSH directory permissions ... ${GREEN}OK${NC}\n"

# disable root login
run_step "Disabling root SSH login" sed -i 's/^#\?PermitRootLogin.*/PermitRootLogin no/' /etc/ssh/sshd_config

run_step "Restarting SSH service" systemctl restart sshd
run_step "Removing password for $USERNAME" passwd -d "$USERNAME"

printf "Setup complete. You can now SSH into $USERNAME ... ${GREEN}OK${NC}\n"
