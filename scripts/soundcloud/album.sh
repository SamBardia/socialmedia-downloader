#!/bin/bash

# Load config
if [ -f "config/soundcloud.conf" ]; then
    source "config/soundcloud.conf"
fi

# Set defaults if config values are missing
AUDIO_FORMAT="${AUDIO_FORMAT:-mp3}"
DOWNLOAD_PATH="${DOWNLOAD_PATH:-downloads/soundcloud}"
MAX_ZIP_SIZE_MB="${MAX_ZIP_SIZE_MB:-90}"
SPLIT_LARGE_FILES="${SPLIT_LARGE_FILES:-true}"

# Get URL from first argument
URL="$1"

# Extract album name from URL (everything after /sets/)
ALBUM_NAME=$(echo "$URL" | sed -n 's|.*/sets/\([^/?]*\).*|\1|p' | sed 's/^./\U&/')

if [ -z "$ALBUM_NAME" ]; then
    echo "Error: Could not extract album name from URL"
    exit 1
fi

echo "Album: $ALBUM_NAME"

# Create download directory
mkdir -p "$DOWNLOAD_PATH"
cd "$DOWNLOAD_PATH"

# Create temporary directory for album
TEMP_DIR="${ALBUM_NAME}_temp"
mkdir -p "$TEMP_DIR"
cd "$TEMP_DIR"

# Download album cover separately
echo "Downloading album cover..."
python3 -m yt_dlp --skip-download --write-thumbnail --convert-thumbnails jpg \
  --output "${ALBUM_NAME} - Pic" \
  "$URL" 2>/dev/null

# Download all tracks as numbered files (always 2-digit numbers)
echo "Downloading tracks..."
python3 -m yt_dlp --extract-audio --audio-format "$AUDIO_FORMAT" \
  --embed-thumbnail --convert-thumbnails jpg \
  --output "%(playlist_index)02d - %(artist)s - %(track)s.%(ext)s" \
  "$URL"

# Check if download was successful
if [ $? -ne 0 ]; then
    echo "Download failed"
    exit 1
fi

# Remove any leftover temp files
rm -f *.webp 2>/dev/null
rm -f *.jpg.* 2>/dev/null

# Go back to download directory
cd ..

# Create ZIP archive
TOTAL_SIZE=$(du -sb "$TEMP_DIR" | cut -f1)
MAX_SIZE_BYTES=$((MAX_ZIP_SIZE_MB * 1024 * 1024))

echo "Creating ZIP archive..."

if [ "$SPLIT_LARGE_FILES" = "true" ] && [ "$TOTAL_SIZE" -gt "$MAX_SIZE_BYTES" ]; then
    echo "Total size exceeds ${MAX_ZIP_SIZE_MB}MB, splitting ZIP into parts"
    zip -s "${MAX_ZIP_SIZE_MB}m" -r "${ALBUM_NAME}.zip" "$TEMP_DIR"
else
    zip -r "${ALBUM_NAME}.zip" "$TEMP_DIR"
fi

# Clean up
rm -rf "$TEMP_DIR"

echo "✅ Album download completed: ${ALBUM_NAME}.zip"
