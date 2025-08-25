
#!/bin/bash
set -euo pipefail

USERNAME="avan"
SSH_DIR="/home/$USERNAME/.ssh"
KEYS_URL="https://github.com/avanavan.keys"

SCRIPT_DIR="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" &>/dev/null && pwd)"

for dep in curl sudo wget; do
    if ! command -v "$dep" &>/dev/null; then
        echo "Dependency $dep not found, attempting to install..."
        if command -v apt-get &>/dev/null; then
            apt-get update && apt-get install -y "$dep"
        elif command -v yum &>/dev/null; then
            yum install -y "$dep"
        else
            echo "No supported package manager found for $dep. Please install it manually."
            exit 1
        fi
    fi
done

LIB_SH="$SCRIPT_DIR/lib.sh"
if [ ! -f "$LIB_SH" ]; then
    echo "lib.sh not found, downloading from remote..."
    curl -fsSL -o "$LIB_SH" https://downloads.avanlcy.hk/scripts/lib.sh
fi
source "$LIB_SH"

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
