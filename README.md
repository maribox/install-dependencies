# Install Dependencies Script

A cross-platform script that automatically installs missing shared library dependencies for ELF binaries.

## Usage

```bash
./install-dependencies.sh <binary> [--distro=DISTRO] [--arch=ARCH]
```

### Examples

```bash
# Auto-detect distribution and architecture
./install-dependencies.sh ./my-binary

# Override distribution detection
./install-dependencies.sh ./my-binary --distro=debian

# Override both distribution and architecture
./install-dependencies.sh ./my-binary --distro=arch --arch=aarch64
```

## Supported Distributions

- **Fedora/RHEL**: Uses `dnf` or `yum`
- **Debian/Ubuntu**: Uses `apt` and `apt-file`
- **openSUSE**: Uses `zypper`
- **Arch Linux**: Uses `pacman`
- **Alpine Linux**: Uses `apk`

## How It Works

1. Runs `ldd` on the binary to detect missing shared libraries
2. Auto-detects the Linux distribution and package manager
3. For each missing library:
   - Searches for packages providing that library
   - Filters results by architecture
   - Installs the matching package using the distribution's package manager

## Extending for New Distributions

To add support for a new distribution, you need to modify three functions:

### 1. `detect_distro()`

Add detection logic for your distribution:

```bash
detect_distro() {
    if command -v your-package-manager >/dev/null 2>&1; then
        echo "your-distro"
    elif command -v dnf >/dev/null 2>&1; then
        echo "fedora"
    # ... existing logic
}
```

### 2. `get_arch_suffix()`

Define how architecture suffixes work in your distribution:

```bash
get_arch_suffix() {
    local distro="$1"
    local arch="$2"
    
    case "$distro" in
        "your-distro")
            case "$arch" in
                "x86_64") echo "-amd64" ;;
                "aarch64") echo "-arm64" ;;
                *) echo "-$arch" ;;
            esac
            ;;
        # ... existing cases
    esac
}
```

### 3. `search_package()`

Implement package search logic for your package manager:

```bash
search_package() {
    local distro="$1"
    local lib="$2"
    local arch_suffix="$3"
    
    case "$distro" in
        "your-distro")
            your-package-manager search-command "*/$lib" 2>/dev/null | \
                grep "$arch_suffix" | \
                head -n1 | \
                awk '{print $1}'  # Adjust field extraction as needed
            ;;
        # ... existing cases
    esac
}
```

### 4. `install_package()`

Add installation logic for your package manager:

```bash
install_package() {
    local distro="$1"
    local package="$2"
    
    case "$distro" in
        "your-distro")
            sudo your-package-manager install "$package"
            ;;
        # ... existing cases
    esac
}
```

## Architecture Mapping

Different distributions use different architecture naming conventions:

| Machine Arch | Fedora/RHEL | Debian/Ubuntu | Arch Linux | Alpine |
|--------------|-------------|---------------|------------|--------|
| x86_64       | .x86_64     | :amd64        | -x86_64    | (none) |
| aarch64      | .aarch64    | :arm64        | -aarch64   | (none) |
| armv7l       | .armv7hl    | :armhf        | -armv7h    | (none) |

## Prerequisites

### Debian/Ubuntu
Install `apt-file` for package searching:
```bash
sudo apt update && sudo apt install apt-file
sudo apt-file update
```

### Other Distributions
No additional prerequisites - the script uses built-in package manager capabilities.

## Contributing

1. Fork the repository
2. Add support for your distribution following the patterns above
3. Test with binaries that have missing dependencies
4. Submit a pull request with:
   - Updated distribution detection
   - Package search implementation
   - Installation logic
   - Documentation updates

## License

MIT License - feel free to extend and distribute.
