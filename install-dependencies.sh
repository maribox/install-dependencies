#!/bin/bash

detect_distro() {
    if command -v dnf >/dev/null 2>&1; then
        echo "fedora"
    elif command -v yum >/dev/null 2>&1; then
        echo "rhel"
    elif command -v apt >/dev/null 2>&1; then
        echo "debian"
    elif command -v zypper >/dev/null 2>&1; then
        echo "opensuse"
    elif command -v pacman >/dev/null 2>&1; then
        echo "arch"
    elif command -v apk >/dev/null 2>&1; then
        echo "alpine"
    else
        echo "unknown"
    fi
}

get_arch_suffix() {
    local distro="$1"
    local arch="$2"
    
    case "$distro" in
        "fedora"|"rhel")
            echo ".$arch"
            ;;
        "debian")
            case "$arch" in
                "x86_64") echo ":amd64" ;;
                "aarch64") echo ":arm64" ;;
                "armv7l") echo ":armhf" ;;
                *) echo ":$arch" ;;
            esac
            ;;
        "opensuse")
            echo ".$arch"
            ;;
        "arch")
            case "$arch" in
                "x86_64") echo "-x86_64" ;;
                "aarch64") echo "-aarch64" ;;
                *) echo "-$arch" ;;
            esac
            ;;
        "alpine")
            echo ""
            ;;
        *)
            echo ".$arch"
            ;;
    esac
}

search_package() {
    local distro="$1"
    local lib="$2"
    local arch_suffix="$3"
    
    case "$distro" in
        "fedora"|"rhel")
            dnf provides "*/$lib" 2>/dev/null | grep "$arch_suffix" | head -n1 | awk '{print $1}' | cut -d':' -f1
            ;;
        "debian")
            apt-file search "$lib" 2>/dev/null | grep "$arch_suffix" | head -n1 | awk -F: '{print $1}'
            ;;
        "opensuse")
            zypper search --provides "*/$lib" 2>/dev/null | grep "$arch_suffix" | awk '{print $3}' | head -n1
            ;;
        "arch")
            pacman -F "$lib" 2>/dev/null | grep -E "^[^/]*/" | head -n1 | awk '{print $2}'
            ;;
        "alpine")
            apk search --exact "$lib" 2>/dev/null | head -n1 | cut -d'-' -f1
            ;;
        *)
            echo ""
            ;;
    esac
}

install_package() {
    local distro="$1"
    local package="$2"
    
    case "$distro" in
        "fedora"|"rhel")
            sudo dnf install -y "$package"
            ;;
        "debian")
            sudo apt update && sudo apt install -y "$package"
            ;;
        "opensuse")
            sudo zypper install -y "$package"
            ;;
        "arch")
            sudo pacman -S --noconfirm "$package"
            ;;
        "alpine")
            sudo apk add "$package"
            ;;
        *)
            echo "Error: Unsupported distribution: $distro"
            return 1
            ;;
    esac
}

if [ $# -eq 0 ]; then
    echo "Usage: $0 <binary> [--distro=DISTRO] [--arch=ARCH]"
    echo ""
    echo "Options:"
    echo "  --distro=DISTRO  Override auto-detected distribution (fedora, rhel, debian, opensuse, arch, alpine)"
    echo "  --arch=ARCH      Override auto-detected architecture"
    echo ""
    echo "Supported distributions:"
    echo "  - Fedora/RHEL (dnf/yum)"
    echo "  - Debian/Ubuntu (apt)"
    echo "  - openSUSE (zypper)"
    echo "  - Arch Linux (pacman)"
    echo "  - Alpine Linux (apk)"
    exit 1
fi

BINARY="$1"
DISTRO=""
ARCH=$(uname -m)

shift
while [[ $# -gt 0 ]]; do
    case $1 in
        --distro=*)
            DISTRO="${1#*=}"
            shift
            ;;
        --arch=*)
            ARCH="${1#*=}"
            shift
            ;;
        *)
            echo "Unknown option: $1"
            exit 1
            ;;
    esac
done

if [ -z "$DISTRO" ]; then
    DISTRO=$(detect_distro)
fi

if [ "$DISTRO" = "unknown" ]; then
    echo "Error: Could not detect supported package manager"
    echo "Supported: dnf, yum, apt, zypper, pacman, apk"
    exit 1
fi

if [ ! -f "$BINARY" ]; then
    echo "Error: Binary '$BINARY' not found"
    exit 1
fi

echo "Distribution: $DISTRO"
echo "Architecture: $ARCH"
echo ""

missing_libs=$(ldd "$BINARY" 2>/dev/null | grep "not found" | awk '{print $1}')

if [ -z "$missing_libs" ]; then
    echo "No missing libraries found"
    exit 0
fi

echo "Found missing libraries:"
echo "$missing_libs"
echo ""

ARCH_SUFFIX=$(get_arch_suffix "$DISTRO" "$ARCH")

for lib in $missing_libs; do
    echo "Searching for package providing $lib..."
    
    package=$(search_package "$DISTRO" "$lib" "$ARCH_SUFFIX")
    
    if [ -z "$package" ]; then
        echo "Warning: No package found for $lib"
        continue
    fi
    
    echo "Installing package: $package"
    if install_package "$DISTRO" "$package"; then
        echo "Successfully installed $package"
    else
        echo "Failed to install $package"
    fi
    echo ""
done

echo "Dependency installation complete"