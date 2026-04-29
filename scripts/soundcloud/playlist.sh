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
# Format: https://soundcloud.com/USERNAME/sets/PLAYLIST_NAME or /playlists/PLAYLIST_NAME
if [[ "$URL" == *"/sets/"* ]]; then
    USERNAME=$(echo "$URL" | sed -n 's|https://soundcloud.com/\([^/]*\)/sets/.*|\1|p')
    PLAYLIST_NAME=$(echo "$URL" | sed -n 's|.*/sets/\([^/?]*\).*|\1|p')
elif [[ "$URL" == *"/playlists/"* ]]; then
    USERNAME=$(echo "$URL" | sed -n 's|https://soundcloud.com/\([^/]*\)/playlists/.*|\1|p')
    PLAYLIST_NAME=$(echo "$URL" | sed -n 's|.*/playlists/\([^/?]*\).*|\1|p')
else
    echo "Error: Could not extract playlist info from URL"
    exit 1
fi

if [ -z "$USERNAME" ] || [ -z "$PLAYLIST_NAME" ]; then
    echo "Error: Could not extract username or playlist name from URL"
    exit 1
fi

# Convert first letter of playlist name to uppercase
PLAYLIST_NAME=$(echo "$PLAYLIST_NAME" | sed 's/^./\U&/')
USERNAME=$(echo "$USERNAME" | sed 's/^./\U&/')

echo "Playlist: $PLAYLIST_NAME by $USERNAME"

# Create download directory
mkdir -p "$DOWNLOAD_PATH"
cd "$DOWNLOAD_PATH"

# Find unique ZIP filename (add number if exists)
BASE_ZIP_NAME="${USERNAME} - ${PLAYLIST_NAME}.zip"
FINAL_ZIP_NAME="$BASE_ZIP_NAME"
COUNTER=1
while [ -f "$FINAL_ZIP_NAME" ]; do
    FINAL_ZIP_NAME="${USERNAME} - ${PLAYLIST_NAME}(${COUNTER}).zip"
    COUNTER=$((COUNTER + 1))
done

# Create temporary directory for playlist
TEMP_DIR="${PLAYLIST_NAME}_temp"
mkdir -p "$TEMP_DIR"
cd "$TEMP_DIR"

# Download all tracks (without track numbers)
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

echo "Creating ZIP archive: $FINAL_ZIP_NAME"

if [ "$SPLIT_LARGE_FILES" = "true" ] && [ "$TOTAL_SIZE" -gt "$MAX_SIZE_BYTES" ]; then
    echo "Total size exceeds ${MAX_ZIP_SIZE_MB}MB, splitting ZIP into parts"
    zip -s "${MAX_ZIP_SIZE_MB}m" -r "$FINAL_ZIP_NAME" "$TEMP_DIR"
else
    zip -r "$FINAL_ZIP_NAME" "$TEMP_DIR"
fi

# Clean up
rm -rf "$TEMP_DIR"

echo "✅ Playlist download completed: $FINAL_ZIP_NAME"
ls -la "${FINAL_ZIP_NAME}"*
