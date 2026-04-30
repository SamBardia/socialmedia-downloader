#!/bin/bash

# ============================================
# Twitter Single Tweet Downloader (Final with duplicate handling)
# Full Persian/Unicode support + Time + Stats + Numbering
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

# Extract username
USERNAME=$(echo "$METADATA" | jq -r '.channel // .uploader_id // empty')
if [ -z "$USERNAME" ]; then
    USERNAME=$(echo "$METADATA" | jq -r '.uploader // empty' | sed 's/[^a-zA-Z0-9_]//g')
fi
USERNAME=$(echo "$USERNAME" | tr '[:upper:]' '[:lower:]')

# Extract full timestamp
TIMESTAMP=$(echo "$METADATA" | jq -r '.timestamp // empty')
if [ -n "$TIMESTAMP" ] && [ "$TIMESTAMP" != "null" ]; then
    TWEET_DATE=$(date -d "@$TIMESTAMP" +'%Y-%m-%d' 2>/dev/null)
    TWEET_TIME=$(date -d "@$TIMESTAMP" +'%H:%M:%S' 2>/dev/null)
else
    TWEET_DATE=$(date +'%Y-%m-%d')
    TWEET_TIME=$(date +'%H:%M:%S')
fi

# Extract tweet ID
TWEET_ID=$(echo "$URL" | grep -oP 'status/\K[0-9]+')
if [ -z "$TWEET_ID" ]; then
    TWEET_ID=$(echo "$METADATA" | jq -r '.id // empty')
fi

# Extract description
DESCRIPTION=$(echo "$METADATA" | jq -r '.description // .title // empty')
if [ -z "$DESCRIPTION" ] || [[ "$DESCRIPTION" == *"\\u"* ]]; then
    DESCRIPTION=$(echo "$METADATA" | jq -r '.title // empty')
fi

# Extract stats
VIEWS=$(echo "$METADATA" | jq -r '.view_count // .views // empty')
LIKES=$(echo "$METADATA" | jq -r '.like_count // .favorite_count // empty')
RETWEETS=$(echo "$METADATA" | jq -r '.retweet_count // .retweets // empty')
REPLIES=$(echo "$METADATA" | jq -r '.reply_count // .replies // empty')

[ -z "$VIEWS" ] || [ "$VIEWS" = "null" ] && VIEWS="N/A"
[ -z "$LIKES" ] || [ "$LIKES" = "null" ] && LIKES="N/A"
[ -z "$RETWEETS" ] || [ "$RETWEETS" = "null" ] && RETWEETS="N/A"
[ -z "$REPLIES" ] || [ "$REPLIES" = "null" ] && REPLIES="N/A"

# Base filename without number
BASE_FILENAME="${USERNAME} - ${TWEET_DATE} - ${TWEET_ID}"

# Check for duplicate and add number if needed
FINAL_ZIP_NAME="${BASE_FILENAME}.zip"
COUNTER=1
while [ -f "$FINAL_ZIP_NAME" ]; do
    FINAL_ZIP_NAME="${BASE_FILENAME}(${COUNTER}).zip"
    COUNTER=$((COUNTER + 1))
done

# Extract the base name without .zip for temp folder
TEMP_DIR="${FINAL_ZIP_NAME%.zip}"

mkdir -p "$TEMP_DIR"
cd "$TEMP_DIR"

# Save description
printf '%s\n' "$DESCRIPTION" > "${TEMP_DIR}.txt"

# Save info
{
    printf 'Tweet ID: %s\n' "$TWEET_ID"
    printf 'Author: %s\n' "$USERNAME"
    printf 'Date: %s\n' "$TWEET_DATE"
    printf 'Time: %s\n' "$TWEET_TIME"
    printf 'URL: %s\n' "$URL"
    printf '---\n'
    printf 'Views: %s\n' "$VIEWS"
    printf 'Likes: %s\n' "$LIKES"
    printf 'Retweets: %s\n' "$RETWEETS"
    printf 'Replies: %s\n' "$REPLIES"
} > "${TEMP_DIR}(info).txt"

# Download media
python3 -m yt_dlp \
    --retries 5 \
    --fragment-retries 5 \
    --ignore-errors \
    --no-abort-on-error \
    --restrict-filenames \
    --output "${TEMP_DIR} - %(playlist_index)02d.%(ext)s" \
    "$URL" 2>/dev/null

# Fix any 'NA' filenames
for file in *NA*; do
    if [ -f "$file" ]; then
        newfile=$(echo "$file" | sed 's/ - NA//' | sed 's/NA - //')
        mv "$file" "$newfile" 2>/dev/null
    fi
done

# Ensure correct numbering for media files
MEDIA_COUNTER=1
for file in $(ls -1 *.mp4 *.jpg *.png *.jpeg *.webm 2>/dev/null | sort); do
    ext="${file##*.}"
    new_name="${TEMP_DIR} - ${MEDIA_COUNTER}.${ext}"
    if [ "$file" != "$new_name" ]; then
        mv "$file" "$new_name" 2>/dev/null
    fi
    MEDIA_COUNTER=$((MEDIA_COUNTER + 1))
done

cd ..

# Create ZIP archive
TOTAL_SIZE=$(du -sb "$TEMP_DIR" | cut -f1)
MAX_SIZE_BYTES=$((MAX_ZIP_SIZE_MB * 1024 * 1024))

if [ "$SPLIT_LARGE_FILES" = "true" ] && [ "$TOTAL_SIZE" -gt "$MAX_SIZE_BYTES" ]; then
    zip -s "${MAX_ZIP_SIZE_MB}m" -r "$FINAL_ZIP_NAME" "$TEMP_DIR"
else
    zip -r "$FINAL_ZIP_NAME" "$TEMP_DIR"
fi

rm -rf "$TEMP_DIR"

echo "SUCCESS: Tweet saved as $FINAL_ZIP_NAME"
ls -la "$FINAL_ZIP_NAME"*
