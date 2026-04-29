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

# Get metadata without downloading
METADATA=$(python3 -m yt_dlp --skip-download --dump-json "$URL" 2>/dev/null)

# Extract artist and title
ARTIST=$(echo "$METADATA" | grep -oP '"artist":\s*"\K[^"]+' | head -1)
if [ -z "$ARTIST" ]; then
    ARTIST=$(echo "$METADATA" | grep -oP '"uploader":\s*"\K[^"]+' | head -1)
fi

TITLE=$(echo "$METADATA" | grep -oP '"track":\s*"\K[^"]+' | head -1)
if [ -z "$TITLE" ]; then
    TITLE=$(echo "$METADATA" | grep -oP '"title":\s*"\K[^"]+' | head -1)
fi

# Clean artist and title from duplicates
# If artist name appears at the beginning of title, remove it
if [[ "$TITLE" == "$ARTIST - "* ]]; then
    TITLE="${TITLE#$ARTIST - }"
fi

# Create final filename
FILENAME="${ARTIST} - ${TITLE}.${AUDIO_FORMAT}"

# Download with custom filename
python3 -m yt_dlp --extract-audio --audio-format "$AUDIO_FORMAT" \
  --output "$FILENAME" \
  "$URL"

# Check if download was successful
if [ $? -eq 0 ]; then
    echo "Single track download completed successfully: $FILENAME"
    # Remove old duplicate files if they exist
    rm -f "* - ${TITLE}.${AUDIO_FORMAT}" 2>/dev/null || true
else
    echo "Download failed"
    exit 1
fi
