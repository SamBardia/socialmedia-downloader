#!/bin/bash

# Load config
source config/soundcloud.conf

# Get URL from first argument
URL="$1"

# Create download directory
mkdir -p "$DOWNLOAD_PATH"

# Change to download directory
cd "$DOWNLOAD_PATH"

# Download single track as MP3
yt-dlp --extract-audio --audio-format "$AUDIO_FORMAT" \
  --output "%(artist)s - %(title)s.%(ext)s" \
  "$URL"

echo "Single track download completed"
