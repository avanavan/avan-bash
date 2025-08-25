#!/bin/bash
set -euo pipefail

SCRIPT_DIR="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" &>/dev/null && pwd)"

dep=curl 
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

INSTALL_SCRIPT="get-docker.sh"

run_step "Fetching Docker install script" curl -fsSL https://get.docker.com -o "$INSTALL_SCRIPT"

run_step "Running Docker install script" sh "$INSTALL_SCRIPT" || true

rm -f "$INSTALL_SCRIPT"
printf "Removed installer script ... ${GREEN}OK${NC}\n"

if command -v docker &>/dev/null; then
	run_step "Adding avan to docker group" usermod -aG docker avan
	printf "Docker installed successfully. Please relogin.\n"
else
	printf "Docker installation failed.\n"
	exit 1
fi
