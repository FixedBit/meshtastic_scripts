#!/bin/bash

# Check if the script is running as root or with sudo
if [[ "$EUID" -ne 0 ]]; then
    echo "This script must be run as root or with sudo privileges."
    exit 1
fi

# Credit banner
display_meshtastic_banner() {
    echo "-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-"
    echo "-=               Meshtastic Setup and Install Script                        =-"
    echo "-=            Simplify your Meshtastic/Meshtasticd setup!                   =-"
    echo "-=                                                                           =-"
    echo "-=    by Jason Hawks - Website: https://fixedbit.com | Discord: fixedbit     =-"
    echo "-=                                                                           =-"
    echo "-=          Shoutout to the North Carolina Meshtastic Community!             =-"
    echo "-=    Website: https://ncmesh.net | Discord: https://discord.gg/xUzRAjHZk8   =-"
    echo "-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-"
}


# Required libraries
REQUIRED_PACKAGES=(
    "libgpiod-dev"
    "libyaml-cpp-dev"
    "libbluetooth-dev"
    "libusb-1.0-0-dev"
    "libi2c-dev"
    "libssl-dev"
    "libulfius-dev"
    "jq"
    "python3"
    "python3-pip"
    "python3-venv"
)

# Function to check if a command exists
check_command() {
    command -v "$1" >/dev/null 2>&1
}

# Function to check and install required libraries
check_and_install_packages() {
    echo "Checking required libraries..."
    MISSING_PACKAGES=()
    for pkg in "${REQUIRED_PACKAGES[@]}"; do
        if ! dpkg-query -W -f='${Status}' "$pkg" 2>/dev/null | grep -q "install ok installed"; then
            MISSING_PACKAGES+=("$pkg")
        fi
    done

    if [ ${#MISSING_PACKAGES[@]} -eq 0 ]; then
        echo "All required libraries are already installed."
        return
    fi

    echo "Missing libraries detected: ${MISSING_PACKAGES[*]}"
    echo "Updating package list and installing missing libraries..."
    sudo apt update -qq
    sudo apt install -y "${MISSING_PACKAGES[@]}"
    echo "Required libraries installed successfully."
}

# Function to determine platform architecture
get_platform() {
    arch=$(uname -m)
    case $arch in
        x86_64) echo "amd64" ;;
        aarch64) echo "arm64" ;;
        armv7l) echo "armhf" ;;
        *) echo "unsupported" ;;
    esac
}

# Function to get the installed version of meshtasticd
get_installed_version() {
    if dpkg -l | grep -q "meshtasticd"; then
        dpkg -s meshtasticd | grep Version | awk '{print $2}'
    else
        echo "none"
    fi
}

# Function to fetch the latest release information
fetch_release_data() {
    release_type=$1
    curl -s "https://api.github.com/repos/meshtastic/firmware/releases" | jq -r --arg type "$release_type" '
    if $type == "Beta" then
        [ .[] | select(.prerelease == false) ] | first
    elif $type == "Alpha" then
        [ .[] | select(.prerelease == true) ] | first
    else
        null
    end
    '
}

# Function to find the asset URL for the selected release
get_release_url() {
    release_data=$1
    platform=$2

    echo "$release_data" |
        jq -r ".assets[] | select(.name | contains(\"${platform}.deb\")) | .browser_download_url"
}

# Function to locate and verify the Meshtastic CLI
check_meshtastic_cli() {
    # Attempt to find meshtastic in the PATH or common installation paths
    MESHTASTIC_CMD=$(command -v meshtastic)

    # Check common paths if not found in PATH
    if [[ -z "$MESHTASTIC_CMD" ]]; then
        local paths=(
            "/opt/meshtastic-venv/bin/meshtastic"
            "/usr/local/bin/meshtastic"
            "/usr/bin/meshtastic"
            "$HOME/.local/bin/meshtastic"
        )
        for path in "${paths[@]}"; do
            if [[ -x "$path" ]]; then
                MESHTASTIC_CMD="$path"
                break
            fi
        done
    fi

    # If still not found, prompt to install
    if [[ -z "$MESHTASTIC_CMD" ]]; then
        echo "Meshtastic CLI is not installed or not in the expected paths."
        read -p "Do you want to install it? (yes/no): [Default: yes] " choice
        choice=${choice:-yes}
        if [[ "$choice" == "yes" ]]; then
            install_meshtastic_cli
        else
            echo "Meshtastic CLI installation skipped. Exiting."
            exit 1
        fi
    fi

    # Verify the Meshtastic CLI works
    if ! "$MESHTASTIC_CMD" --help >/dev/null 2>&1; then
        echo "Error: Meshtastic CLI is installed but not functioning correctly."
        echo "Please check your installation or reinstall the Meshtastic CLI."
        exit 1
    fi

    echo "Meshtastic CLI is installed and functioning correctly: $MESHTASTIC_CMD"
}

# Function to install Meshtastic CLI
install_meshtastic_cli() {
    local venv_path="/opt/meshtastic-venv"

    echo "Creating Python virtual environment..."
    if [[ ! -d "$venv_path" ]]; then
        sudo python3 -m venv "$venv_path"
    fi

    echo "Installing Meshtastic Python library in virtual environment..."
    sudo "$venv_path/bin/pip" install meshtastic

    echo "Adding Meshtastic command to global PATH if not already present..."
    local profile_script="/etc/profile.d/meshtastic.sh"
    local export_line="export PATH=\"$venv_path/bin:\$PATH\""

    if ! grep -qF "$export_line" "$profile_script" 2>/dev/null; then
        sudo bash -c "echo '$export_line' > $profile_script"
        sudo chmod 0755 "$profile_script"
        echo "Added Meshtastic to global PATH via $profile_script."
    else
        echo "Global PATH already includes Meshtastic command."
    fi

    # Add to user's shell configuration files
    for shell_rc in "$HOME/.bashrc" "$HOME/.zshrc"; do
        if [[ -f "$shell_rc" ]] && ! grep -qF "$export_line" "$shell_rc"; then
            echo "$export_line" >> "$shell_rc"
            echo "Added Meshtastic to PATH in $shell_rc."
        fi
    done

    # Source the changes for the current session
    export PATH="$venv_path/bin:$PATH"
    echo "Meshtastic CLI installation completed successfully."
}

# Function to back up the current meshtasticd configuration
backup_meshtasticd_config() {
    local backup_dir="/root/meshtastic_prefs_backup"
    local config_dir="/root/.portduino/default/prefs"

    if [[ -d "$config_dir" ]]; then
        echo "Would you like to back up your current Meshtasticd configuration before proceeding? (yes/no) [Default: yes]"
        read -r backup_choice
        backup_choice=${backup_choice:-yes}

        if [[ "$backup_choice" == "yes" ]]; then
            echo "Overwriting any existing backup in $backup_dir..."
            sudo mkdir -p "$backup_dir"
            sudo rm -f "$backup_dir"/*.proto # Remove existing backups
            sudo cp "$config_dir"/*.proto "$backup_dir/"
            echo "Backup completed. Your configuration has been saved to $backup_dir."
            echo "To restore your configuration, run the following commands:"
            echo "sudo mkdir -p $config_dir"
            echo "sudo cp $backup_dir/*.proto $config_dir/"
        else
            echo "Backup skipped."
        fi
    else
        echo "No existing configuration found to back up."
    fi
}


# Function to install or update meshtasticd
install_or_update_meshtasticd() {
    platform=$(get_platform)
    if [ "$platform" == "unsupported" ]; then
        echo "Unsupported platform architecture: $(uname -m)"
        exit 1
    fi

    echo "Do you want to install or update Meshtasticd?"
    echo "1) Alpha"
    echo "2) Beta (default)"
    read -p "Selection: " selection
    selection=${selection:-2}

    if [ "$selection" == "1" ]; then
        release_type="Alpha"
    else
        release_type="Beta"
    fi

    # Fetch release data
    release_data=$(fetch_release_data "$release_type")
    if [ -z "$release_data" ] || [ "$release_data" == "null" ]; then
        echo "Failed to fetch release data. Please check your internet connection or the release type."
        exit 1
    fi

    # Get release tag and asset URL
    release_tag=$(echo "$release_data" | jq -r ".tag_name")
    release_url=$(get_release_url "$release_data" "$platform")

    if [ -z "$release_url" ]; then
        echo "Could not find a suitable release for platform: $platform"
        exit 1
    fi

    # Check installed version
    installed_version=$(get_installed_version)
    if [ "$installed_version" == "${release_tag/v/}" ]; then
        echo "You already have the latest version installed: $installed_version"
        return
    fi

    # Backup existing configuration
    backup_meshtasticd_config

    # Download and install the release
    tmp_dir=$(mktemp -d)
    file_name="${tmp_dir}/meshtasticd_${release_tag}_${platform}.deb"

    echo "Downloading $release_tag for $platform..."
    curl -L -s "$release_url" -o "$file_name"

    echo "Installing the package..."
    sudo DEBIAN_FRONTEND=noninteractive apt install -y "$file_name" --allow-downgrades -o Dpkg::Options::="--force-confold" 2>/dev/null || {
        echo "Failed to install the package. Please check dependencies."
        rm -rf "$tmp_dir"
        exit 1
    }

    # Cleanup
    rm -rf "$tmp_dir"
    echo "Meshtasticd installation completed successfully!"

    # Check and handle meshtasticd service
    if systemctl is-enabled meshtasticd >/dev/null 2>&1; then
        echo "Meshtasticd service is enabled. Restarting it now..."
        sudo systemctl restart meshtasticd
    else
        read -p "Meshtasticd service is not enabled. Do you want to enable it? (yes/no) [Default: yes]: " enable_choice
        enable_choice=${enable_choice:-yes}
        if [[ "$enable_choice" == "yes" ]]; then
            echo "Enabling and starting Meshtasticd service..."
            sudo systemctl enable --now meshtasticd && sudo systemctl start meshtasticd
        else
            echo "Meshtasticd service not enabled."
        fi
    fi
}

echo "-= Meshtastic Setup and Install Script =-"

# Main script logic
check_and_install_packages

check_meshtastic_cli

# Always ask to install or update meshtasticd
install_or_update_meshtasticd

# Display the banner
display_meshtastic_banner

# reboot note
echo "NOTE: If this is your first time installing Meshtastic, please reboot your device to apply the changes."
