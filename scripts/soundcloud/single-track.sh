#!/bin/bash

# Load config
if [ -f "config/soundcloud.conf" ]; then
    source "config/soundcloud.conf"
fi

# Set defaults if config values are missing
AUDIO_FORMAT="${AUDIO_FORMAT:-mp3}"
DOWNLOAD_PATH="${DOWNLOAD_PATH:-downloads/soundcloud}"

# Get URL from first argument
URL="$1"

# Create download directory
mkdir -p "$DOWNLOAD_PATH"

# Change to download directory
cd "$DOWNLOAD_PATH"

# Download using python module
python3 -m yt_dlp --extract-audio --audio-format "$AUDIO_FORMAT" \
  --output "%(artist)s - %(track)s.%(ext)s" \
  "$URL"

# Check if download was successful
if [ $? -eq 0 ]; then
    echo "Single track download completed successfully"
else
    echo "Download failed"
    exit 1
fi
