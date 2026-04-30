#!/bin/bash

# ============================================
# SoundCloud Album Downloader
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

# Extract album name from URL (everything after /sets/)
ALBUM_NAME=$(echo "$URL" | sed -n 's|.*/sets/\([^/?]*\).*|\1|p' | sed 's/^./\U&/')
if [ -z "$ALBUM_NAME" ]; then
    echo "ERROR: Could not extract album name from URL"
    exit 1
fi

# Clean album name
ALBUM_NAME=$(echo "$ALBUM_NAME" | sed 's/[\/\\:*?"<>|]/_/g' | sed 's/[[:space:]]/_/g' | sed 's/__*/_/g' | sed 's/^_//;s/_$//')
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

# Create temporary directory for album
TEMP_DIR="temp_${ALBUM_NAME}"
mkdir -p "$TEMP_DIR"
cd "$TEMP_DIR"

# Download album cover thumbnail
echo "Downloading album cover..."
python3 -m yt_dlp --skip-download --write-thumbnail --convert-thumbnails jpg \
  --retries 10 \
  --retry-sleep exp=1:60 \
  --output "${ALBUM_NAME} - Pic" \
  "$URL" 2>/dev/null

# Download all tracks with track numbers
echo "Downloading album tracks..."
python3 -m yt_dlp --extract-audio --audio-format "$AUDIO_FORMAT" \
  --embed-thumbnail --convert-thumbnails jpg \
  --retries 10 \
  --fragment-retries 10 \
  --retry-sleep exp=1:60 \
  --sleep-interval 3 \
  --max-sleep-interval 10 \
  --limit-rate 500K \
  --output "%(playlist_index)02d - %(artist)s - %(track)s.%(ext)s" \
  "$URL"

if [ $? -ne 0 ]; then
    echo "ERROR: Download failed"
    exit 1
fi

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

echo "SUCCESS: Album download completed - $FINAL_ZIP_NAME"
ls -la "${FINAL_ZIP_NAME}"*
