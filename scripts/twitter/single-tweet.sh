#!/bin/bash

# ============================================
# Twitter Single Tweet Downloader (Final)
# با پشتیبانی از توییت‌های قفل‌شده یا حذف شده
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

# ============================================
# Extract username from URL (most reliable)
# ============================================
USERNAME=$(echo "$URL" | grep -oP 'x\.com/\K[^/]+')
if [ -z "$USERNAME" ]; then
    USERNAME=$(echo "$URL" | grep -oP 'twitter\.com/\K[^/]+')
fi
if [ -z "$USERNAME" ]; then
    USERNAME="unknown_user"
fi
USERNAME=$(echo "$USERNAME" | tr '[:upper:]' '[:lower:]')

# ============================================
# Extract tweet ID from URL
# ============================================
TWEET_ID=$(echo "$URL" | grep -oP 'status/\K[0-9]+')
if [ -z "$TWEET_ID" ]; then
    TWEET_ID="unknown_id"
fi

# ============================================
# Get metadata (if available)
# ============================================
METADATA=$(python3 -m yt_dlp --skip-download --dump-json "$URL" 2>/dev/null)

# ============================================
# Extract date from metadata or use current date
# ============================================
TIMESTAMP=$(echo "$METADATA" | jq -r '.timestamp // empty')
if [ -n "$TIMESTAMP" ] && [ "$TIMESTAMP" != "null" ]; then
    TWEET_DATE=$(date -d "@$TIMESTAMP" +'%Y-%m-%d' 2>/dev/null)
    TWEET_TIME=$(date -d "@$TIMESTAMP" +'%H:%M:%S' 2>/dev/null)
else
    TWEET_DATE=$(date +'%Y-%m-%d')
    TWEET_TIME=$(date +'%H:%M:%S')
fi

# ============================================
# Extract description from multiple sources
# ============================================
DESCRIPTION=$(echo "$METADATA" | jq -r '.description // empty')
if [ -z "$DESCRIPTION" ]; then
    DESCRIPTION=$(echo "$METADATA" | jq -r '.title // empty')
    DESCRIPTION=$(echo "$DESCRIPTION" | sed 's/^X 上的 //' | sed 's/ \/ X$//')
fi
if [ -z "$DESCRIPTION" ]; then
    DESCRIPTION=$(echo "$METADATA" | jq -r '.text // empty')
fi
if [ -z "$DESCRIPTION" ]; then
    DESCRIPTION=$(echo "$METADATA" | jq -r '.content // empty')
fi
if [ -z "$DESCRIPTION" ]; then
    DESCRIPTION=$(echo "$METADATA" | jq -r '.full_text // empty')
fi
if [ -z "$DESCRIPTION" ]; then
    DESCRIPTION="[Tweet content not available - possibly deleted or private]"
fi

# ============================================
# Handle duplicate files
# ============================================
BASE_FILENAME="${USERNAME} - ${TWEET_DATE} - ${TWEET_ID}"

FINAL_ZIP_NAME="${BASE_FILENAME}.zip"
COUNTER=1
while [ -f "$FINAL_ZIP_NAME" ]; do
    FINAL_ZIP_NAME="${BASE_FILENAME}(${COUNTER}).zip"
    COUNTER=$((COUNTER + 1))
done

TEMP_DIR="${FINAL_ZIP_NAME%.zip}"

mkdir -p "$TEMP_DIR"
cd "$TEMP_DIR"

# ============================================
# Save description
# ============================================
printf '%s\n' "$DESCRIPTION" > "${TEMP_DIR}.txt"

# ============================================
# Save info file
# ============================================
{
    printf 'Tweet ID: %s\n' "$TWEET_ID"
    printf 'Author: %s\n' "$USERNAME"
    printf 'Date: %s\n' "$TWEET_DATE"
    printf 'Time: %s\n' "$TWEET_TIME"
    printf 'URL: %s\n' "$URL"
} > "${TEMP_DIR}(info).txt"

# ============================================
# Download media (if any)
# ============================================
python3 -m yt_dlp \
    --retries 5 \
    --fragment-retries 5 \
    --ignore-errors \
    --no-abort-on-error \
    --restrict-filenames \
    --output "${TEMP_DIR} - %(playlist_index)02d.%(ext)s" \
    "$URL" 2>/dev/null

# Rename media files
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

# ============================================
# Create ZIP
# ============================================
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
