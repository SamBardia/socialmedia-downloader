#!/bin/bash
# ============================================
# SoundCloud album/playlist downloader
# ============================================

if [ -f "config/soundcloud.conf" ]; then
    source "config/soundcloud.conf"
fi

AUDIO_FORMAT="${AUDIO_FORMAT:-mp3}"
DOWNLOAD_PATH="${DOWNLOAD_PATH:-downloads/soundcloud}"
MAX_ZIP_SIZE_MB="${MAX_ZIP_SIZE_MB:-90}"
SPLIT_LARGE_FILES="${SPLIT_LARGE_FILES:-true}"

URL="$1"

# Extract collection name from URL
COLLECTION_NAME=$(echo "$URL" | sed -n 's|.*/sets/\([^/?]*\).*|\1|p')
if [ -z "$COLLECTION_NAME" ]; then
    COLLECTION_NAME=$(echo "$URL" | sed -n 's|.*/playlists/\([^/?]*\).*|\1|p')
fi
if [ -z "$COLLECTION_NAME" ]; then
    echo "ERROR: Could not extract collection name"
    exit 1
fi

COLLECTION_NAME=$(echo "$COLLECTION_NAME" | sed 's/[\/\\:*?"<>|]/_/g' | sed 's/[[:space:]]\+/_/g')
COLLECTION_NAME="$(echo "${COLLECTION_NAME:0:1}" | tr '[:lower:]' '[:upper:]')${COLLECTION_NAME:1}"

mkdir -p "$DOWNLOAD_PATH"
cd "$DOWNLOAD_PATH"

# Handle duplicate ZIP files
BASE_ZIP_NAME="${COLLECTION_NAME}.zip"
FINAL_ZIP_NAME="$BASE_ZIP_NAME"
COUNT=1
while [ -f "$FINAL_ZIP_NAME" ]; do
    FINAL_ZIP_NAME="${COLLECTION_NAME}(${COUNT}).zip"
    COUNT=$((COUNT + 1))
done

TEMP_DIR="${COLLECTION_NAME} Album"
mkdir -p "$TEMP_DIR"
cd "$TEMP_DIR"
# Fix artist names with unicode comma
for file in *.mp3; do
    [ -f "$file" ] || continue
    newname=$(echo "$file" | sed 's/，/,/g' | sed 's/،/,/g' | sed 's/,/ \& /g')
    [ "$file" != "$newname" ] && mv "$file" "$newname" 2>/dev/null
done
# Download cover art (best effort)
python3 -m yt_dlp --skip-download --write-thumbnail --convert-thumbnails jpg \
    --output "${COLLECTION_NAME}_cover" "$URL" 2>/dev/null

# Download all tracks with track numbers
python3 -m yt_dlp --extract-audio --audio-format "$AUDIO_FORMAT" \
    --embed-thumbnail --convert-thumbnails jpg \
    --retries 10 --fragment-retries 10 --retry-sleep exp=1:60 \
    --sleep-interval 3 --max-sleep-interval 10 --limit-rate 500K \
    --ignore-errors --no-abort-on-error \
    --output "%(playlist_index)02d - %(artist)s - %(track)s.%(ext)s" "$URL"

cd ..
TOTAL_SIZE=$(du -sb "$TEMP_DIR" | cut -f1)
MAX_SIZE_BYTES=$((MAX_ZIP_SIZE_MB * 1024 * 1024))

if [ "$SPLIT_LARGE_FILES" = "true" ] && [ "$TOTAL_SIZE" -gt "$MAX_SIZE_BYTES" ]; then
    zip -s "${MAX_ZIP_SIZE_MB}m" -r "$FINAL_ZIP_NAME" "$TEMP_DIR"
else
    zip -r "$FINAL_ZIP_NAME" "$TEMP_DIR"
fi

rm -rf "$TEMP_DIR"
echo "SUCCESS: $FINAL_ZIP_NAME"
ls -la "$FINAL_ZIP_NAME"*
