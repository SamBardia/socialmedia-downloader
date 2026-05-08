#!/bin/bash

# ============================================
# Twitter Single Tweet Downloader
# Downloads media if present, otherwise saves text and metadata.
# Includes like_count, repost_count, reply_count, view_count
# ============================================

if [ -f "config/twitter.conf" ]; then
    source "config/twitter.conf"
fi

DOWNLOAD_PATH="${DOWNLOAD_PATH:-downloads}"
MAX_ZIP_SIZE_MB="${MAX_ZIP_SIZE_MB:-90}"
SPLIT_LARGE_FILES="${SPLIT_LARGE_FILES:-true}"

URL="$1"

# Helper function to sanitize filenames
sanitize_filename() {
    echo "$1" | sed 's/[\/\\:*?"<>|]/_/g' | sed 's/[[:space:]]\+/_/g' | sed 's/^_//;s/_$//'
}

mkdir -p "$DOWNLOAD_PATH"
cd "$DOWNLOAD_PATH"

# Extract username from URL
USERNAME=$(echo "$URL" | grep -oP 'x\.com/\K[^/]+')
if [ -z "$USERNAME" ]; then
    USERNAME=$(echo "$URL" | grep -oP 'twitter\.com/\K[^/]+')
fi
USERNAME=$(echo "$USERNAME" | sanitize_filename)
[ -z "$USERNAME" ] && USERNAME="unknown"

# Extract tweet ID from URL
TWEET_ID=$(echo "$URL" | grep -oP 'status/\K[0-9]+')
if [ -z "$TWEET_ID" ]; then
    echo "ERROR: Could not extract tweet ID from URL"
    exit 1
fi

# Get metadata from yt-dlp (using dump-json for processing)
METADATA=$(python3 -m yt_dlp --skip-download --dump-json "$URL" 2>/dev/null)

# Check if tweet has media (thumbnails array has elements)
HAS_MEDIA=false
MEDIA_COUNT=$(echo "$METADATA" | jq -r '.thumbnails // empty | length' 2>/dev/null)
if [ -n "$MEDIA_COUNT" ] && [ "$MEDIA_COUNT" -gt 0 ]; then
    HAS_MEDIA=true
fi

# Extract tweet text (description)
DESCRIPTION=$(echo "$METADATA" | jq -r '.description // empty')
if [ -z "$DESCRIPTION" ]; then
    DESCRIPTION=$(echo "$METADATA" | jq -r '.title // empty')
    DESCRIPTION=$(echo "$DESCRIPTION" | sed 's/^X 上的 //' | sed 's/ \/ X$//')
fi
if [ -z "$DESCRIPTION" ]; then
    DESCRIPTION="[Text content not available]"
fi

# Extract date and time
TIMESTAMP=$(echo "$METADATA" | jq -r '.timestamp // empty')
if [ -n "$TIMESTAMP" ] && [ "$TIMESTAMP" != "null" ]; then
    TWEET_DATE=$(date -d "@$TIMESTAMP" +'%Y-%m-%d' 2>/dev/null)
    TWEET_TIME=$(date -d "@$TIMESTAMP" +'%H:%M:%S' 2>/dev/null)
else
    TWEET_DATE=$(date +'%Y-%m-%d')
    TWEET_TIME=$(date +'%H:%M:%S')
fi

# Extract stats
LIKE_COUNT=$(echo "$METADATA" | jq -r '.like_count // empty')
REPOST_COUNT=$(echo "$METADATA" | jq -r '.repost_count // .retweet_count // empty')
REPLY_COUNT=$(echo "$METADATA" | jq -r '.reply_count // .comment_count // empty')
VIEW_COUNT=$(echo "$METADATA" | jq -r '.view_count // empty')

# Convert empty or null to "N/A"
[ -z "$LIKE_COUNT" ] || [ "$LIKE_COUNT" = "null" ] && LIKE_COUNT="N/A"
[ -z "$REPOST_COUNT" ] || [ "$REPOST_COUNT" = "null" ] && REPOST_COUNT="N/A"
[ -z "$REPLY_COUNT" ] || [ "$REPLY_COUNT" = "null" ] && REPLY_COUNT="N/A"
[ -z "$VIEW_COUNT" ] || [ "$VIEW_COUNT" = "null" ] && VIEW_COUNT="N/A"

# Base filename for the tweet
BASE_FILENAME="${USERNAME} - ${TWEET_DATE} - ${TWEET_ID}"
TEMP_DIR="${BASE_FILENAME}"
mkdir -p "$TEMP_DIR"
cd "$TEMP_DIR" || exit 1

# Save the tweet text
echo "$DESCRIPTION" > "${BASE_FILENAME}.txt"

# Save metadata with all stats
{
    echo "Tweet ID: $TWEET_ID"
    echo "Author: $USERNAME"
    echo "Date: $TWEET_DATE"
    echo "Time: $TWEET_TIME"
    echo "URL: $URL"
    echo "--- Stats ---"
    echo "Likes: $LIKE_COUNT"
    echo "Reposts: $REPOST_COUNT"
    echo "Replies: $REPLY_COUNT"
    echo "Views: $VIEW_COUNT"
    echo "Has Media: $HAS_MEDIA"
} > "${BASE_FILENAME}(info).txt"

if [ "$HAS_MEDIA" = true ]; then
    echo "Tweet has media. Downloading..."
    # Download media files
    python3 -m yt_dlp \
        --retries 10 \
        --fragment-retries 10 \
        --ignore-errors \
        --no-abort-on-error \
        --restrict-filenames \
        --output "${BASE_FILENAME} - %(playlist_index)02d.%(ext)s" \
        "$URL" 2>/dev/null

    # Rename media files sequentially
    MEDIA_COUNTER=1
    for file in $(ls -1 *.mp4 *.jpg *.png *.jpeg *.webm 2>/dev/null | sort); do
        if [ -f "$file" ]; then
            ext="${file##*.}"
            new_name="${BASE_FILENAME} - ${MEDIA_COUNTER}.${ext}"
            mv "$file" "$new_name" 2>/dev/null
            MEDIA_COUNTER=$((MEDIA_COUNTER + 1))
        fi
    done
fi

# Go back to the download directory
cd ..

# Create the final ZIP archive
if [ -d "$TEMP_DIR" ] && [ "$(ls -A "$TEMP_DIR" 2>/dev/null)" ]; then
    # Handle duplicate ZIP files
    FINAL_ZIP_NAME="${BASE_FILENAME}.zip"
    COUNT=1
    while [ -f "$FINAL_ZIP_NAME" ]; do
        FINAL_ZIP_NAME="${BASE_FILENAME}(${COUNT}).zip"
        COUNT=$((COUNT + 1))
    done
    
    zip -r "$FINAL_ZIP_NAME" "$TEMP_DIR"
    rm -rf "$TEMP_DIR"
    echo "SUCCESS: Tweet saved as $FINAL_ZIP_NAME"
    ls -la "$FINAL_ZIP_NAME"
else
    echo "ERROR: No content was saved for this tweet."
    rm -rf "$TEMP_DIR"
    exit 1
fi
