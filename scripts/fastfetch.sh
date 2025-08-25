#!/bin/bash
set -euo pipefail

SCRIPT_DIR="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" &>/dev/null && pwd)"

LIB_SH="$SCRIPT_DIR/lib.sh"
if [ ! -f "$LIB_SH" ]; then
    echo "lib.sh not found in $SCRIPT_DIR"
    exit 1
fi
source "$LIB_SH"

SUDO=""
if [ "$EUID" -ne 0 ]; then
    if command -v sudo &>/dev/null; then
        SUDO=sudo
    else
        echo "This script needs root privileges to install packages. Re-run as root or install sudo." >&2
        exit 1
    fi
fi

version_ge() {
    # compare version strings like 20.04, 11, 13
    # prefer dpkg --compare-versions if available
    if command -v dpkg &>/dev/null; then
        dpkg --compare-versions "$1" ge "$2"
        return $?
    fi
    # fallback to sort -V
    [ "$(printf "%s\n%s" "$1" "$2" | sort -V | tail -n1)" = "$1" ]
}

detect_os() {
    if [ -r /etc/os-release ]; then
        . /etc/os-release
        ID_LC=$(echo "$ID" | tr '[:upper:]' '[:lower:]')
        VERSION_ID_LC=${VERSION_ID:-}
        ID_LIKE=${ID_LIKE:-}
        echo "$ID_LC" "$VERSION_ID_LC" "$ID_LIKE"
        return 0
    fi
    # fallback basic detection
    if command -v apk &>/dev/null; then
        echo "alpine" "" ""
        return 0
    fi
    if command -v pacman &>/dev/null; then
        echo "arch" "" ""
        return 0
    fi
    echo "unknown" "" ""
}

arch_asset() {
    local m
    m=$(uname -m)
    case "$m" in
        x86_64) echo "x86_64" ;;
        aarch64) echo "aarch64" ;;
        armv7l) echo "armv7l" ;;
        i686|i386) echo "i686" ;;
        *) echo "$m" ;;
    esac
}

install_deb_from_github() {
    local arch asset url dst
    arch=$(arch_asset)
    asset="fastfetch-linux-${arch}.deb"
    url="https://github.com/fastfetch/fastfetch/releases/latest/download/${asset}"
    dst="/tmp/${asset}"

    run_step "Downloading ${asset}" $SUDO curl -fsSL -o "$dst" "$url"

    run_step "Installing ${asset}" $SUDO dpkg -i "$dst" || true
    # fix deps if dpkg left them unresolved
    if command -v apt-get &>/dev/null; then
        run_step "Fixing missing dependencies" $SUDO apt-get install -y -f
    fi
    rm -f "$dst"
}

main() {
    read -r ID VERSION ID_LIKE < <(detect_os)
    # Ensure ID_LIKE has a value to prevent "unbound variable" errors
    ID_LIKE=${ID_LIKE:-""}

    case "$ID" in
        debian)
            if [ -n "$VERSION" ] && version_ge "$VERSION" "13"; then
                run_step "Refreshing apt cache" $SUDO apt-get update
                run_step "Installing fastfetch (apt)" $SUDO apt-get install -y fastfetch
            elif [ -n "$VERSION" ] && version_ge "$VERSION" "11"; then
                install_deb_from_github
            else
                # fallback to apt-get
                run_step "Refreshing apt cache" $SUDO apt-get update
                run_step "Installing fastfetch (apt-get)" $SUDO apt-get install -y fastfetch
            fi
            ;;
        ubuntu)
            # Ubuntu 20.04 is 20.04
            if [ -n "$VERSION" ] && version_ge "$VERSION" "20.04"; then
                install_deb_from_github
            else
                run_step "Refreshing apt cache" $SUDO apt-get update
                run_step "Installing fastfetch (apt)" $SUDO apt-get install -y fastfetch
            fi
            ;;
        arch|manjaro)
            run_step "Installing fastfetch (pacman)" $SUDO pacman -S --noconfirm fastfetch
            ;;
        fedora)
            run_step "Installing fastfetch (dnf)" $SUDO dnf install -y fastfetch
            ;;
        gentoo)
            run_step "Installing fastfetch (emerge)" $SUDO emerge --ask app-misc/fastfetch
            ;;
        alpine)
            run_step "Installing fastfetch (apk)" $SUDO apk add --upgrade fastfetch
            ;;
        nixos)
            run_step "Installing fastfetch (nix-shell)" nix-shell -p fastfetch --run true
            ;;
        opensuse*|suse)
            run_step "Installing fastfetch (zypper)" $SUDO zypper --non-interactive install fastfetch
            ;;
        alt|altlinux|altlinux*)
            run_step "Installing fastfetch (apt-get)" $SUDO apt-get update && $SUDO apt-get install -y fastfetch
            ;;
        exherbo)
            run_step "Installing fastfetch (cave)" $SUDO cave resolve --execute app-misc/fastfetch
            ;;
        solus)
            run_step "Installing fastfetch (eopkg)" $SUDO eopkg install -y fastfetch
            ;;
        slackware)
            run_step "Installing fastfetch (sbopkg)" $SUDO sbopkg -i fastfetch
            ;;
        void)
            run_step "Installing fastfetch (xbps)" $SUDO xbps-install -y fastfetch
            ;;
        venom)
            run_step "Installing fastfetch (scratch)" $SUDO scratch install fastfetch
            ;;
        *)
            # try common package managers
            if command -v pacman &>/dev/null; then
                run_step "Installing fastfetch (pacman)" $SUDO pacman -S --noconfirm fastfetch
            elif command -v apt-get &>/dev/null; then
                run_step "Refreshing apt cache" $SUDO apt-get update
                run_step "Installing fastfetch (apt-get)" $SUDO apt-get install -y fastfetch
            elif command -v dnf &>/dev/null; then
                run_step "Installing fastfetch (dnf)" $SUDO dnf install -y fastfetch
            else
                printf "No known package manager detected. Please install fastfetch manually.\n"
                exit 1
            fi
            ;;
    esac

    if command -v fastfetch &>/dev/null; then
        run_step "Generating default fastfetch config" fastfetch --gen-config-full
        printf "fastfetch installed and configured successfully.\n"
        exit 0
    else
        printf "fastfetch not found after installation attempts.\n"
        exit 1
    fi
}

main "$@"
