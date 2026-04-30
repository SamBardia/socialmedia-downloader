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

# Extract username and playlist name from URL
if [[ "$URL" == *"/sets/"* ]]; then
    USERNAME=$(echo "$URL" | sed -n 's|https://soundcloud.com/\([^/]*\)/sets/.*|\1|p')
    PLAYLIST_NAME_RAW=$(echo "$URL" | sed -n 's|.*/sets/\([^/?]*\).*|\1|p')
elif [[ "$URL" == *"/playlists/"* ]]; then
    USERNAME=$(echo "$URL" | sed -n 's|https://soundcloud.com/\([^/]*\)/playlists/.*|\1|p')
    PLAYLIST_NAME_RAW=$(echo "$URL" | sed -n 's|.*/playlists/\([^/?]*\).*|\1|p')
else
    echo "Error: Could not extract playlist info from URL"
    exit 1
fi

if [ -z "$USERNAME" ] || [ -z "$PLAYLIST_NAME_RAW" ]; then
    echo "Error: Could not extract username or playlist name from URL"
    exit 1
fi

# Clean username (remove invalid chars)
USERNAME=$(echo "$USERNAME" | sed 's/[\/\\:*?"<>|]/_/g' | sed 's/[[:space:]]/_/g' | sed 's/__*/_/g' | sed 's/^_//;s/_$//')

# Check if playlist name contains Persian characters
if echo "$PLAYLIST_NAME_RAW" | grep -qP '[\x{0600}-\x{06FF}]'; then
    PLAYLIST_NAME="Playlist"
else
    PLAYLIST_NAME=$(echo "$PLAYLIST_NAME_RAW" | sed 's/^./\U&/')
fi

# Remove invalid characters from playlist name
PLAYLIST_NAME=$(echo "$PLAYLIST_NAME" | sed 's/[\/\\:*?"<>|]/_/g' | sed 's/[[:space:]]/_/g' | sed 's/__*/_/g' | sed 's/^_//;s/_$//')

echo "Playlist: $PLAYLIST_NAME"
echo "Username: $USERNAME"

# Create download directory
mkdir -p "$DOWNLOAD_PATH"
cd "$DOWNLOAD_PATH"

# Find unique ZIP filename
BASE_ZIP_NAME="${PLAYLIST_NAME}.zip"
FINAL_ZIP_NAME="$BASE_ZIP_NAME"
COUNTER=1
while [ -f "$FINAL_ZIP_NAME" ]; do
    FINAL_ZIP_NAME="${PLAYLIST_NAME}(${COUNTER}).zip"
    COUNTER=$((COUNTER + 1))
done

echo "ZIP file will be: $FINAL_ZIP_NAME"

# Create temporary directory for playlist
TEMP_DIR="temp_${PLAYLIST_NAME}"
mkdir -p "$TEMP_DIR"
cd "$TEMP_DIR"

# Download all tracks
echo "Downloading playlist tracks..."
python3 -m yt_dlp --extract-audio --audio-format "$AUDIO_FORMAT" \
  --embed-thumbnail --convert-thumbnails jpg \
  --retries 10 \
  --fragment-retries 10 \
  --retry-sleep exp=1:60 \
  --sleep-interval 3 \
  --max-sleep-interval 10 \
  --limit-rate 500K \
  --output "%(artist)s - %(track)s.%(ext)s" \
  "$URL"

# Check if download was successful
if [ $? -ne 0 ]; then
    echo "Download failed"
    exit 1
fi

# Go back to download directory
cd ..

# Check if temp directory has any files
FILE_COUNT=$(find "$TEMP_DIR" -type f -name "*.mp3" 2>/dev/null | wc -l)
echo "Found $FILE_COUNT MP3 files in temp directory"

if [ "$FILE_COUNT" -eq 0 ]; then
    echo "No MP3 files were downloaded"
    rm -rf "$TEMP_DIR"
    exit 1
fi

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

# Check if ZIP was created successfully
if [ -f "$FINAL_ZIP_NAME" ] || [ -f "${FINAL_ZIP_NAME%.zip}.z01" ]; then
    echo "✅ Playlist download completed: $FINAL_ZIP_NAME"
    ls -la "${FINAL_ZIP_NAME}"* 2>/dev/null || ls -la "${FINAL_ZIP_NAME%.zip}".z* 2>/dev/null
else
    echo "ZIP creation failed"
    exit 1
fi

# Clean up
rm -rf "$TEMP_DIR"
