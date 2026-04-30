#!/bin/bash

if [ -f "config/soundcloud.conf" ]; then
    source "config/soundcloud.conf"
fi

AUDIO_FORMAT="${AUDIO_FORMAT:-mp3}"
DOWNLOAD_PATH="${DOWNLOAD_PATH:-downloads/soundcloud}"
MAX_ZIP_SIZE_MB="${MAX_ZIP_SIZE_MB:-90}"
SPLIT_LARGE_FILES="${SPLIT_LARGE_FILES:-true}"

URL="$1"

PLAYLIST_NAME_RAW=$(echo "$URL" | sed -n 's|.*/sets/\([^/?]*\).*|\1|p')
if [ -z "$PLAYLIST_NAME_RAW" ]; then
    PLAYLIST_NAME_RAW=$(echo "$URL" | sed -n 's|.*/playlists/\([^/?]*\).*|\1|p')
fi

if echo "$PLAYLIST_NAME_RAW" | grep -qP '[\x{0600}-\x{06FF}]'; then
    PLAYLIST_NAME="Playlist"
else
    PLAYLIST_NAME=$(echo "$PLAYLIST_NAME_RAW" | sed 's/^./\U&/')
fi

PLAYLIST_NAME=$(echo "$PLAYLIST_NAME" | sed 's/[\/\\:*?"<>|]/_/g' | sed 's/[[:space:]]/_/g' | sed 's/__*/_/g' | sed 's/^_//;s/_$//')
echo "Playlist: $PLAYLIST_NAME"

mkdir -p "$DOWNLOAD_PATH"
cd "$DOWNLOAD_PATH"

BASE_ZIP_NAME="${PLAYLIST_NAME}.zip"
FINAL_ZIP_NAME="$BASE_ZIP_NAME"
COUNTER=1
while [ -f "$FINAL_ZIP_NAME" ]; do
    FINAL_ZIP_NAME="${PLAYLIST_NAME}(${COUNTER}).zip"
    COUNTER=$((COUNTER + 1))
done

python3 -m yt_dlp --extract-audio --audio-format "$AUDIO_FORMAT" \
  --embed-thumbnail --convert-thumbnails jpg \
  --retries 10 --fragment-retries 10 --retry-sleep exp=1:60 \
  --sleep-interval 3 --max-sleep-interval 10 --limit-rate 500K \
  --output "%(artist)s - %(track)s.%(ext)s" "$URL"

if [ $? -ne 0 ]; then
    echo "Download failed"
    exit 1
fi

FILE_COUNT=$(find . -maxdepth 1 -type f -name "*.mp3" | wc -l)
if [ "$FILE_COUNT" -eq 0 ]; then
    echo "No MP3 files downloaded"
    exit 1
fi

TOTAL_SIZE=$(du -sb . | cut -f1)
MAX_SIZE_BYTES=$((MAX_ZIP_SIZE_MB * 1024 * 1024))

if [ "$SPLIT_LARGE_FILES" = "true" ] && [ "$TOTAL_SIZE" -gt "$MAX_SIZE_BYTES" ]; then
    zip -s "${MAX_ZIP_SIZE_MB}m" -r "$FINAL_ZIP_NAME" . -x "*.zip" "*.z*"
else
    zip -r "$FINAL_ZIP_NAME" . -x "*.zip" "*.z*"
fi

rm -f *.mp3 *.jpg *.webp 2>/dev/null
echo "Playlist download completed: $FINAL_ZIP_NAME"
