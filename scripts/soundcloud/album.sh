#!/bin/bash

# ============================================
# SoundCloud Collection Downloader (Album & Playlist)
# Always numbers tracks, no distinction between album and playlist
# ============================================

# Load configuration file
if [ -f "config/soundcloud.conf" ]; then
    source "config/soundcloud.conf"
fi

# Set default values if config is missing
AUDIO_FORMAT="${AUDIO_FORMAT:-mp3}"
DOWNLOAD_PATH="${DOWNLOAD_PATH:-downloads/soundcloud}"
MAX_ZIP_SIZE_MB="${MAX_ZIP_SIZE_MB:-90}"
SPLIT_LARGE_FILES="${SPLIT_LARGE_FILES:-true}"

# Get URL from first argument
URL="$1"

# Extract collection name from URL
COLLECTION_NAME=$(echo "$URL" | sed -n 's|.*/sets/\([^/?]*\).*|\1|p')
if [ -z "$COLLECTION_NAME" ]; then
    COLLECTION_NAME=$(echo "$URL" | sed -n 's|.*/playlists/\([^/?]*\).*|\1|p')
fi

if [ -z "$COLLECTION_NAME" ]; then
    echo "ERROR: Could not extract collection name from URL"
    exit 1
fi

# Clean collection name (remove invalid chars ONLY, keep spaces)
COLLECTION_NAME=$(echo "$COLLECTION_NAME" | sed 's/[\/\\:*?"<>|]/_/g')
COLLECTION_NAME=$(echo "$COLLECTION_NAME" | sed 's/^[[:space:]]*//;s/[[:space:]]*$//')

# Capitalize first letter of collection name
COLLECTION_NAME="$(echo "${COLLECTION_NAME:0:1}" | tr '[:lower:]' '[:upper:]')${COLLECTION_NAME:1}"

# Add " Album" suffix for folder name
FOLDER_NAME="${COLLECTION_NAME} Album"
ZIP_NAME="${COLLECTION_NAME}.zip"

echo "Collection: $COLLECTION_NAME"
echo "Folder: $FOLDER_NAME"
echo "ZIP file will be: $ZIP_NAME"

# Create download directory
mkdir -p "$DOWNLOAD_PATH"
cd "$DOWNLOAD_PATH"

# Find unique ZIP filename (add number if exists)
BASE_ZIP_NAME="$ZIP_NAME"
FINAL_ZIP_NAME="$BASE_ZIP_NAME"
COUNTER=1
while [ -f "$FINAL_ZIP_NAME" ]; do
    FINAL_ZIP_NAME="${COLLECTION_NAME}(${COUNTER}).zip"
    COUNTER=$((COUNTER + 1))
done

echo "Final ZIP file: $FINAL_ZIP_NAME"

# Create temporary directory for collection
TEMP_DIR="$FOLDER_NAME"
mkdir -p "$TEMP_DIR"
cd "$TEMP_DIR"

# Download album cover thumbnail (best effort)
echo "Downloading cover art..."
python3 -m yt_dlp --skip-download --write-thumbnail --convert-thumbnails jpg \
  --retries 10 \
  --retry-sleep exp=1:60 \
  --output "${COLLECTION_NAME} - Pic" \
  "$URL" 2>/dev/null

# Download all tracks with track numbers (always 2 digits)
# --ignore-errors and --no-abort-on-error allow skipping failed tracks
echo "Downloading tracks..."
python3 -m yt_dlp --extract-audio --audio-format "$AUDIO_FORMAT" \
  --embed-thumbnail --convert-thumbnails jpg \
  --retries 10 \
  --fragment-retries 10 \
  --retry-sleep exp=1:60 \
  --sleep-interval 3 \
  --max-sleep-interval 10 \
  --limit-rate 500K \
  --ignore-errors \
  --no-abort-on-error \
  --output "%(playlist_index)02d - %(artist)s - %(track)s.%(ext)s" \
  "$URL"

# Clean up temporary files
rm -f *.webp 2>/dev/null
rm -f *.jpg.* 2>/dev/null

# Go back to download directory
cd ..

# Create ZIP archive
TOTAL_SIZE=$(du -sb "$TEMP_DIR" | cut -f1)
MAX_SIZE_BYTES=$((MAX_ZIP_SIZE_MB * 1024 * 1024))

echo "Creating ZIP archive: $FINAL_ZIP_NAME"

if [ "$SPLIT_LARGE_FILES" = "true" ] && [ "$TOTAL_SIZE" -gt "$MAX_SIZE_BYTES" ]; then
    echo "File exceeds ${MAX_ZIP_SIZE_MB}MB, splitting into parts"
    zip -s "${MAX_ZIP_SIZE_MB}m" -r "$FINAL_ZIP_NAME" "$TEMP_DIR"
else
    zip -r "$FINAL_ZIP_NAME" "$TEMP_DIR"
fi

# Clean up
rm -rf "$TEMP_DIR"

echo "SUCCESS: Collection download completed - $FINAL_ZIP_NAME"
ls -la "${FINAL_ZIP_NAME}"*
