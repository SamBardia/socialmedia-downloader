#!/bin/bash

# ============================================
# Twitter Single Tweet Downloader
# ============================================

if [ -f "config/twitter.conf" ]; then
    source "config/twitter.conf"
fi

DOWNLOAD_PATH="${DOWNLOAD_PATH:-downloads/twitter}"
MAX_ZIP_SIZE_MB="${MAX_ZIP_SIZE_MB:-90}"
SPLIT_LARGE_FILES="${SPLIT_LARGE_FILES:-true}"

URL="$1"

mkdir -p "$DOWNLOAD_PATH"
cd "$DOWNLOAD_PATH"

METADATA=$(python3 -m yt_dlp --skip-download --dump-json "$URL" 2>/dev/null)

USERNAME=$(echo "$METADATA" | grep -oP '"uploader":\s*"\K[^"]+' | head -1)
if [ -z "$USERNAME" ]; then
    USERNAME=$(echo "$METADATA" | grep -oP '"channel":\s*"\K[^"]+' | head -1)
fi
USERNAME=$(echo "$USERNAME" | sed 's/^[[:space:]]*//;s/[[:space:]]*$//')

TIMESTAMP=$(echo "$METADATA" | grep -oP '"timestamp":\s*[0-9]+' | grep -oP '[0-9]+')
if [ -n "$TIMESTAMP" ]; then
    TWEET_DATE=$(date -d "@$TIMESTAMP" +'%Y-%m-%d' 2>/dev/null)
else
    TWEET_DATE=$(date +'%Y-%m-%d')
fi

TWEET_ID=$(echo "$URL" | grep -oP 'status/\K[0-9]+')
if [ -z "$TWEET_ID" ]; then
    TWEET_ID=$(echo "$METADATA" | grep -oP '"id":\s*[0-9]+' | head -1 | grep -oP '[0-9]+')
fi

DESCRIPTION=$(echo "$METADATA" | grep -oP '"description":\s*"\K[^"]+' | head -1)
if [ -z "$DESCRIPTION" ]; then
    DESCRIPTION=$(echo "$METADATA" | grep -oP '"title":\s*"\K[^"]+' | head -1)
fi

VIEWS=$(echo "$METADATA" | grep -oP '"view_count":\s*[0-9]+' | grep -oP '[0-9]+')
LIKES=$(echo "$METADATA" | grep -oP '"like_count":\s*[0-9]+' | grep -oP '[0-9]+')
RETWEETS=$(echo "$METADATA" | grep -oP '"retweet_count":\s*[0-9]+' | grep -oP '[0-9]+')
REPLIES=$(echo "$METADATA" | grep -oP '"reply_count":\s*[0-9]+' | grep -oP '[0-9]+')

BASE_FILENAME="${USERNAME} - ${TWEET_DATE} - ${TWEET_ID}"

TEMP_DIR="${BASE_FILENAME}"
mkdir -p "$TEMP_DIR"
cd "$TEMP_DIR"

# Always save text and info
echo "$DESCRIPTION" > "${BASE_FILENAME}.txt"

{
    echo "Tweet ID: $TWEET_ID"
    echo "Author: $USERNAME"
    echo "Date: $TWEET_DATE"
    echo "URL: $URL"
    echo "---"
    echo "Views: ${VIEWS:-N/A}"
    echo "Likes: ${LIKES:-N/A}"
    echo "Retweets: ${RETWEETS:-N/A}"
    echo "Replies: ${REPLIES:-N/A}"
} > "${BASE_FILENAME}(info).txt"

# Download media (continue even if fails)
python3 -m yt_dlp \
    --retries 5 \
    --fragment-retries 5 \
    --ignore-errors \
    --no-abort-on-error \
    --output "${BASE_FILENAME} - %(playlist_index)02d.%(ext)s" \
    "$URL" 2>/dev/null

# Rename only successfully downloaded media files
COUNTER=1
for file in $(ls -1 *.jpg *.png *.jpeg *.mp4 *.webm 2>/dev/null | sort); do
    if [ -f "$file" ]; then
        ext="${file##*.}"
        new_name="${BASE_FILENAME} - ${COUNTER}.${ext}"
        mv "$file" "$new_name" 2>/dev/null
        COUNTER=$((COUNTER + 1))
    fi
done

cd ..

# Always create ZIP (even if no media, just txt and info)
TOTAL_SIZE=$(du -sb "$TEMP_DIR" | cut -f1)
MAX_SIZE_BYTES=$((MAX_ZIP_SIZE_MB * 1024 * 1024))

if [ "$SPLIT_LARGE_FILES" = "true" ] && [ "$TOTAL_SIZE" -gt "$MAX_SIZE_BYTES" ]; then
    zip -s "${MAX_ZIP_SIZE_MB}m" -r "${BASE_FILENAME}.zip" "$TEMP_DIR"
else
    zip -r "${BASE_FILENAME}.zip" "$TEMP_DIR"
fi

rm -rf "$TEMP_DIR"

echo "SUCCESS: Tweet saved as ${BASE_FILENAME}.zip"
ls -la "${BASE_FILENAME}.zip"*
