#!/bin/bash

# ============================================
# Twitter Single Tweet Downloader (Final)
# Full Persian/Unicode support
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

# Extract username (channel/uploader_id) - clean version
USERNAME=$(echo "$METADATA" | jq -r '.channel // .uploader_id // empty')
if [ -z "$USERNAME" ]; then
    USERNAME=$(echo "$METADATA" | jq -r '.uploader // empty' | sed 's/[^a-zA-Z0-9_]//g')
fi
USERNAME=$(echo "$USERNAME" | tr '[:upper:]' '[:lower:]')

# Extract tweet date
TIMESTAMP=$(echo "$METADATA" | jq -r '.timestamp // empty')
if [ -n "$TIMESTAMP" ] && [ "$TIMESTAMP" != "null" ]; then
    TWEET_DATE=$(date -d "@$TIMESTAMP" +'%Y-%m-%d' 2>/dev/null)
else
    TWEET_DATE=$(date +'%Y-%m-%d')
fi

# Extract tweet ID
TWEET_ID=$(echo "$URL" | grep -oP 'status/\K[0-9]+')
if [ -z "$TWEET_ID" ]; then
    TWEET_ID=$(echo "$METADATA" | jq -r '.id // empty')
fi

# Extract description with Persian/Unicode support
DESCRIPTION=$(echo "$METADATA" | jq -r '.description // .title // empty')

# If description is still empty or has encoding issues, try alternative
if [ -z "$DESCRIPTION" ] || [[ "$DESCRIPTION" == *"\\u"* ]]; then
    DESCRIPTION=$(echo "$METADATA" | jq -r '.title // empty')
fi

# Extract stats
VIEWS=$(echo "$METADATA" | jq -r '.view_count // empty')
LIKES=$(echo "$METADATA" | jq -r '.like_count // empty')
RETWEETS=$(echo "$METADATA" | jq -r '.retweet_count // empty')
REPLIES=$(echo "$METADATA" | jq -r '.reply_count // empty')

BASE_FILENAME="${USERNAME} - ${TWEET_DATE} - ${TWEET_ID}"

TEMP_DIR="${BASE_FILENAME}"
mkdir -p "$TEMP_DIR"
cd "$TEMP_DIR"

# Save description with UTF-8 encoding (Persian-safe)
printf '%s\n' "$DESCRIPTION" > "${BASE_FILENAME}.txt"

# Save info
{
    printf 'Tweet ID: %s\n' "$TWEET_ID"
    printf 'Author: %s\n' "$USERNAME"
    printf 'Date: %s\n' "$TWEET_DATE"
    printf 'URL: %s\n' "$URL"
    printf '---\n'
    printf 'Views: %s\n' "${VIEWS:-N/A}"
    printf 'Likes: %s\n' "${LIKES:-N/A}"
    printf 'Retweets: %s\n' "${RETWEETS:-N/A}"
    printf 'Replies: %s\n' "${REPLIES:-N/A}"
} > "${BASE_FILENAME}(info).txt"

# Download media
python3 -m yt_dlp \
    --retries 5 \
    --fragment-retries 5 \
    --ignore-errors \
    --no-abort-on-error \
    --restrict-filenames \
    --output "${BASE_FILENAME} - %(playlist_index)02d.%(ext)s" \
    "$URL" 2>/dev/null

# Fix any 'NA' filenames
for file in *NA*; do
    if [ -f "$file" ]; then
        newfile=$(echo "$file" | sed 's/ - NA//' | sed 's/NA - //')
        mv "$file" "$newfile" 2>/dev/null
    fi
done

# Ensure correct numbering for media files
COUNTER=1
for file in $(ls -1 *.mp4 *.jpg *.png *.jpeg *.webm 2>/dev/null | sort); do
    ext="${file##*.}"
    new_name="${BASE_FILENAME} - ${COUNTER}.${ext}"
    if [ "$file" != "$new_name" ]; then
        mv "$file" "$new_name" 2>/dev/null
    fi
    COUNTER=$((COUNTER + 1))
done

cd ..

# Create ZIP archive
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
