#!/bin/bash

# Convert Windows paths to WSL paths
wsl_path() {
    echo "$1" | sed 's/\\/\//g' | sed 's/^\([A-Za-z]\):/\/mnt\/\L\1/'
}

# Check if deploy-config exists
if [ ! -f deploy-config ]; then
    echo "deploy-config not found. Creating from template..."
    cp deploy-config.template deploy-config
    echo "Please edit deploy-config with your settings"
    exit 1
fi

# Source the config file (after converting line endings)
source <(tr -d '\r' < deploy-config)

# Validate config
if [ -z "$FACTORIO_MODS_DIR" ]; then
    echo "FACTORIO_MODS_DIR not set in deploy-config"
    exit 1
fi

if [ -z "$VERSION" ]; then
    echo "VERSION not set in deploy-config"
    exit 1
fi

MOD_NAME="replay-timelapse"
MOD_FULL_NAME="${MOD_NAME}_${VERSION}"

# Create zip file
echo "Creating ${MOD_FULL_NAME}.zip..."
rm -f "${MOD_FULL_NAME}.zip"
zip -r "${MOD_FULL_NAME}.zip" "${MOD_NAME}"

# Convert Windows path to WSL path and copy
WSL_MODS_DIR=$(wsl_path "$FACTORIO_MODS_DIR")
echo "Copying to $WSL_MODS_DIR..."
mkdir -p "$WSL_MODS_DIR"
cp "${MOD_FULL_NAME}.zip" "$WSL_MODS_DIR"

echo "Done!" 