#!/bin/bash

# ============================================
# SoundCloud Single Track Downloader
# ============================================

# Load configuration file
if [ -f "config/soundcloud.conf" ]; then
    source "config/soundcloud.conf"
fi

# Set default values if config is missing
AUDIO_FORMAT="${AUDIO_FORMAT:-mp3}"
DOWNLOAD_PATH="${DOWNLOAD_PATH:-downloads/soundcloud}"

# Get URL from first argument
URL="$1"

# Create download directory
mkdir -p "$DOWNLOAD_PATH"
cd "$DOWNLOAD_PATH"

# Get metadata without downloading the file
METADATA=$(python3 -m yt_dlp --skip-download --dump-json "$URL" 2>/dev/null)

# Extract artist name
ARTIST=$(echo "$METADATA" | grep -oP '"artist":\s*"\K[^"]+' | head -1)
if [ -z "$ARTIST" ]; then
    ARTIST=$(echo "$METADATA" | grep -oP '"uploader":\s*"\K[^"]+' | head -1)
fi

# STEP 1: Replace unicode fullwidth comma with regular comma
ARTIST=$(echo "$ARTIST" | sed 's/\\uff0c/,/g' | sed 's/،/,/g')

# STEP 2: Replace commas with " & " (space-ampersand-space)
ARTIST=$(echo "$ARTIST" | sed 's/[[:space:]]*,[[:space:]]*/ \& /g')

# STEP 3: Clean artist name (remove invalid chars, replace spaces with underscore)
ARTIST=$(echo "$ARTIST" | sed 's/[\/\\:*?"<>|]/_/g' | sed 's/[[:space:]]/_/g' | sed 's/__*/_/g' | sed 's/^_//;s/_$//')

# Extract track title
TITLE=$(echo "$METADATA" | grep -oP '"track":\s*"\K[^"]+' | head -1)
if [ -z "$TITLE" ]; then
    TITLE=$(echo "$METADATA" | grep -oP '"title":\s*"\K[^"]+' | head -1)
fi

# Clean title: remove invalid characters
TITLE=$(echo "$TITLE" | sed 's/[\/\\:*?"<>|]/_/g' | sed 's/[[:space:]]/_/g' | sed 's/__*/_/g' | sed 's/^_//;s/_$//')

# Remove artist name from title if it appears at the beginning
if [[ "$TITLE" == "$ARTIST"* ]]; then
    TITLE="${TITLE#$ARTIST}"
    TITLE=$(echo "$TITLE" | sed 's/^[ _-]*//')
fi

# Build base filename
BASE_FILENAME="${ARTIST} - ${TITLE}"
EXTENSION="$AUDIO_FORMAT"

# Handle duplicate files by adding numbers
FINAL_FILENAME="${BASE_FILENAME}.${EXTENSION}"
COUNTER=1
while [ -f "$FINAL_FILENAME" ]; do
    FINAL_FILENAME="${BASE_FILENAME}(${COUNTER}).${EXTENSION}"
    COUNTER=$((COUNTER + 1))
done

echo "Downloading: $FINAL_FILENAME"

# Download track with cover art and retry logic
python3 -m yt_dlp --extract-audio --audio-format "$AUDIO_FORMAT" \
  --embed-thumbnail --convert-thumbnails jpg \
  --retries 10 \
  --fragment-retries 10 \
  --retry-sleep exp=1:60 \
  --sleep-interval 3 \
  --max-sleep-interval 10 \
  --limit-rate 500K \
  --output "$FINAL_FILENAME" \
  "$URL"

# Check if download was successful
if [ $? -eq 0 ]; then
    echo "SUCCESS: Single track downloaded - $FINAL_FILENAME"
else
    echo "ERROR: Download failed"
    exit 1
fi
