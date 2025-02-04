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

# Convert Windows path to WSL path
WSL_MODS_DIR=$(wsl_path "$FACTORIO_MODS_DIR")

# Remove old version if it exists
echo "Removing old version if it exists..."
rm -rf "$WSL_MODS_DIR/$MOD_FULL_NAME"

# Copy mod directory with versioned name
echo "Copying to $WSL_MODS_DIR/$MOD_FULL_NAME..."
cp -r "$MOD_NAME" "$WSL_MODS_DIR/$MOD_FULL_NAME"

echo "Done!" 