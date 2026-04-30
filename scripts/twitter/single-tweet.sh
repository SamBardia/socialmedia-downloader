#!/bin/bash

# ============================================
# Twitter Single Tweet Downloader (Final)
# Full Persian/Unicode support + Time + Numbering
# Without stats (views, likes, retweets, replies)
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

# ============================================
# Extract username with multiple fallbacks
# ============================================
USERNAME=$(echo "$METADATA" | jq -r '.channel // .uploader_id // empty')
if [ -z "$USERNAME" ]; then
    USERNAME=$(echo "$METADATA" | jq -r '.uploader // empty')
    # Remove emojis and special chars from display name
    USERNAME=$(echo "$USERNAME" | perl -CSD -pe 's/[^\w\s\-]//g' 2>/dev/null || echo "$USERNAME" | sed 's/[^a-zA-Z0-9 ]//g')
    USERNAME=$(echo "$USERNAME" | sed 's/^[[:space:]]*//;s/[[:space:]]*$//')
    USERNAME=$(echo "$USERNAME" | sed 's/[[:space:]]\+/_/g')
fi
if [ -z "$USERNAME" ]; then
    USERNAME=$(echo "$METADATA" | jq -r '.display_id // empty')
fi
# Extract username from URL if still empty
if [ -z "$USERNAME" ]; then
    USERNAME=$(echo "$URL" | grep -oP 'x\.com/\K[^/]+')
fi
if [ -z "$USERNAME" ]; then
    USERNAME=$(echo "$URL" | grep -oP 'twitter\.com/\K[^/]+')
fi
if [ -z "$USERNAME" ]; then
    USERNAME="unknown_user"
fi
USERNAME=$(echo "$USERNAME" | tr '[:upper:]' '[:lower:]')

# ============================================
# Extract full timestamp
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
# Extract tweet ID
# ============================================
TWEET_ID=$(echo "$URL" | grep -oP 'status/\K[0-9]+')
if [ -z "$TWEET_ID" ]; then
    TWEET_ID=$(echo "$METADATA" | jq -r '.id // empty')
fi

# ============================================
# Extract description with multiple fallbacks
# ============================================
DESCRIPTION=$(echo "$METADATA" | jq -r '.description // empty')
if [ -z "$DESCRIPTION" ]; then
    DESCRIPTION=$(echo "$METADATA" | jq -r '.title // empty')
    # Remove "X 上的 " prefix and trailing " / X" if present
    DESCRIPTION=$(echo "$DESCRIPTION" | sed 's/^X 上的 //' | sed 's/ \/ X$//')
    # If after cleaning it's just the username or empty, try other fields
    if [ -z "$DESCRIPTION" ] || [[ "$DESCRIPTION" == "$USERNAME" ]]; then
        DESCRIPTION=""
    fi
fi
if [ -z "$DESCRIPTION" ]; then
    DESCRIPTION=$(echo "$METADATA" | jq -r '.alt_title // empty')
fi
if [ -z "$DESCRIPTION" ]; then
    DESCRIPTION=$(echo "$METADATA" | jq -r '.webpage_url // empty')
fi
if [ -z "$DESCRIPTION" ]; then
    DESCRIPTION="Tweet contains only a link (no additional text)"
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
# Save description with UTF-8 encoding
# ============================================
printf '%s\n' "$DESCRIPTION" > "${TEMP_DIR}.txt"

# ============================================
# Save info file (without stats)
# ============================================
{
    printf 'Tweet ID: %s\n' "$TWEET_ID"
    printf 'Author: %s\n' "$USERNAME"
    printf 'Date: %s\n' "$TWEET_DATE"
    printf 'Time: %s\n' "$TWEET_TIME"
    printf 'URL: %s\n' "$URL"
} > "${TEMP_DIR}(info).txt"

# ============================================
# Download media (ignore errors)
# ============================================
python3 -m yt_dlp \
    --retries 5 \
    --fragment-retries 5 \
    --ignore-errors \
    --no-abort-on-error \
    --restrict-filenames \
    --output "${TEMP_DIR} - %(playlist_index)02d.%(ext)s" \
    "$URL" 2>/dev/null

# ============================================
# Fix 'NA' filenames and rename media files
# ============================================
for file in *NA*; do
    if [ -f "$file" ]; then
        newfile=$(echo "$file" | sed 's/ - NA//' | sed 's/NA - //')
        mv "$file" "$newfile" 2>/dev/null
    fi
done

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
# Create ZIP archive (with splitting if needed)
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
