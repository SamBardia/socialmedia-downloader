#!/bin/bash
# ============================================
# Twitter single tweet with media downloader
# text-only tweets are ignored
# ============================================

if [ -f "config/twitter.conf" ]; then
    source "config/twitter.conf"
fi

DOWNLOAD_PATH="${DOWNLOAD_PATH:-downloads/twitter}"

URL="$1"

USERNAME=$(echo "$URL" | grep -oP 'x\.com/\K[^/]+')
if [ -z "$USERNAME" ]; then
    USERNAME=$(echo "$URL" | grep -oP 'twitter\.com/\K[^/]+')
fi
USERNAME=$(echo "$USERNAME" | tr '[:upper:]' '[:lower:]' | sed 's/[^a-z0-9_]//g')
[ -z "$USERNAME" ] && USERNAME="unknown"

TWEET_ID=$(echo "$URL" | grep -oP 'status/\K[0-9]+')
if [ -z "$TWEET_ID" ]; then
    echo "ERROR: Could not extract tweet ID"
    exit 1
fi

METADATA=$(python3 -m yt_dlp --skip-download --dump-json "$URL" 2>/dev/null)
HAS_MEDIA=$(echo "$METADATA" | jq -r '.thumbnails // empty | length')
if [ -z "$HAS_MEDIA" ] || [ "$HAS_MEDIA" -eq 0 ]; then
    echo "INFO: No media, skipping"
    exit 0
fi

TIMESTAMP=$(echo "$METADATA" | jq -r '.timestamp // empty')
if [ -n "$TIMESTAMP" ] && [ "$TIMESTAMP" != "null" ]; then
    TWEET_DATE=$(date -d "@$TIMESTAMP" +'%Y-%m-%d')
    TWEET_TIME=$(date -d "@$TIMESTAMP" +'%H:%M:%S')
else
    TWEET_DATE=$(date +'%Y-%m-%d')
    TWEET_TIME=$(date +'%H:%M:%S')
fi

BASE_FILENAME="${USERNAME} - ${TWEET_DATE} - ${TWEET_ID}"
mkdir -p "$DOWNLOAD_PATH"
cd "$DOWNLOAD_PATH"

FINAL_ZIP_NAME="${BASE_FILENAME}.zip"
COUNT=1
while [ -f "$FINAL_ZIP_NAME" ]; do
    FINAL_ZIP_NAME="${BASE_FILENAME}(${COUNT}).zip"
    COUNT=$((COUNT + 1))
done

TEMP_DIR="${FINAL_ZIP_NAME%.zip}"
mkdir -p "$TEMP_DIR"
cd "$TEMP_DIR"

# Save tweet text and info
echo "$METADATA" | jq -r '.description // .title // "No text"' > "${BASE_FILENAME}.txt"
{
    echo "Tweet ID: $TWEET_ID"
    echo "Author: $USERNAME"
    echo "Date: $TWEET_DATE"
    echo "Time: $TWEET_TIME"
    echo "URL: $URL"
} > "${BASE_FILENAME}(info).txt"

python3 -m yt_dlp --retries 5 --fragment-retries 5 --ignore-errors --no-abort-on-error \
    --restrict-filenames --output "${BASE_FILENAME} - %(playlist_index)02d.%(ext)s" "$URL" 2>/dev/null

# Rename media sequentially
COUNT=1
for f in $(ls -1 *.jpg *.png *.jpeg *.mp4 *.webm 2>/dev/null | sort); do
    ext="${f##*.}"
    mv "$f" "${BASE_FILENAME} - ${COUNT}.${ext}" 2>/dev/null
    COUNT=$((COUNT + 1))
done

cd ..
zip -r "$FINAL_ZIP_NAME" "$TEMP_DIR"
rm -rf "$TEMP_DIR"
echo "SUCCESS: $FINAL_ZIP_NAME"
