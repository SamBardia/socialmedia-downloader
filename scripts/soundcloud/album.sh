#!/bin/bash

if [ -f "config/soundcloud.conf" ]; then
    source "config/soundcloud.conf"
fi

AUDIO_FORMAT="${AUDIO_FORMAT:-mp3}"
DOWNLOAD_PATH="${DOWNLOAD_PATH:-downloads/soundcloud}"
MAX_ZIP_SIZE_MB="${MAX_ZIP_SIZE_MB:-90}"
SPLIT_LARGE_FILES="${SPLIT_LARGE_FILES:-true}"

URL="$1"

ALBUM_NAME=$(echo "$URL" | sed -n 's|.*/sets/\([^/?]*\).*|\1|p' | sed 's/^./\U&/')
if [ -z "$ALBUM_NAME" ]; then
    echo "Error: Could not extract album name"
    exit 1
fi

ALBUM_NAME=$(echo "$ALBUM_NAME" | sed 's/[\/\\:*?"<>|]/_/g' | sed 's/[[:space:]]/_/g' | sed 's/__*/_/g' | sed 's/^_//;s/_$//')
echo "Album: $ALBUM_NAME"

mkdir -p "$DOWNLOAD_PATH"
cd "$DOWNLOAD_PATH"

BASE_ZIP_NAME="${ALBUM_NAME}.zip"
FINAL_ZIP_NAME="$BASE_ZIP_NAME"
COUNTER=1
while [ -f "$FINAL_ZIP_NAME" ]; do
    FINAL_ZIP_NAME="${ALBUM_NAME}(${COUNTER}).zip"
    COUNTER=$((COUNTER + 1))
done

TEMP_DIR="temp_${ALBUM_NAME}"
mkdir -p "$TEMP_DIR"
cd "$TEMP_DIR"

python3 -m yt_dlp --skip-download --write-thumbnail --convert-thumbnails jpg \
  --output "${ALBUM_NAME} - Pic" "$URL" 2>/dev/null

python3 -m yt_dlp --extract-audio --audio-format "$AUDIO_FORMAT" \
  --embed-thumbnail --convert-thumbnails jpg \
  --retries 10 --fragment-retries 10 --retry-sleep exp=1:60 \
  --sleep-interval 3 --max-sleep-interval 10 --limit-rate 500K \
  --output "%(playlist_index)02d - %(artist)s - %(track)s.%(ext)s" "$URL"

if [ $? -ne 0 ]; then
    echo "Download failed"
    exit 1
fi

cd ..

TOTAL_SIZE=$(du -sb "$TEMP_DIR" | cut -f1)
MAX_SIZE_BYTES=$((MAX_ZIP_SIZE_MB * 1024 * 1024))

if [ "$SPLIT_LARGE_FILES" = "true" ] && [ "$TOTAL_SIZE" -gt "$MAX_SIZE_BYTES" ]; then
    zip -s "${MAX_ZIP_SIZE_MB}m" -r "$FINAL_ZIP_NAME" "$TEMP_DIR"
else
    zip -r "$FINAL_ZIP_NAME" "$TEMP_DIR"
fi

rm -rf "$TEMP_DIR"
echo "Album download completed: $FINAL_ZIP_NAME"
