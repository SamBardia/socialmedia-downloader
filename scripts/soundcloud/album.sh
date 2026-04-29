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

# Find unique ZIP filename (add number if exists)
BASE_ZIP_NAME="${ALBUM_NAME}.zip"
FINAL_ZIP_NAME="$BASE_ZIP_NAME"
COUNTER=1
while [ -f "$FINAL_ZIP_NAME" ]; do
    FINAL_ZIP_NAME="${ALBUM_NAME}(${COUNTER}).zip"
    COUNTER=$((COUNTER + 1))
done

# Create temporary directory for album (with " Album" suffix)
TEMP_DIR="${ALBUM_NAME} Album"
mkdir -p "$TEMP_DIR"
cd "$TEMP_DIR"

# Download best quality album cover
echo "Downloading album cover (best quality)..."
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

# Remove any leftover temp files (low quality thumbnails)
rm -f *.webp 2>/dev/null
rm -f *.jpg.* 2>/dev/null

# Go back to download directory
cd ..

# Create ZIP archive
TOTAL_SIZE=$(du -sb "$TEMP_DIR" | cut -f1)
MAX_SIZE_BYTES=$((MAX_ZIP_SIZE_MB * 1024 * 1024))

echo "Creating ZIP archive: $FINAL_ZIP_NAME"

if [ "$SPLIT_LARGE_FILES" = "true" ] && [ "$TOTAL_SIZE" -gt "$MAX_SIZE_BYTES" ]; then
    echo "Total size exceeds ${MAX_ZIP_SIZE_MB}MB, splitting ZIP into parts"
    zip -s "${MAX_ZIP_SIZE_MB}m" -r "$FINAL_ZIP_NAME" "$TEMP_DIR"
else
    zip -r "$FINAL_ZIP_NAME" "$TEMP_DIR"
fi

# Clean up
rm -rf "$TEMP_DIR"

echo "✅ Album download completed: $FINAL_ZIP_NAME"
ls -la "${FINAL_ZIP_NAME}"*
