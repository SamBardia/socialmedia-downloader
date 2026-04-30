#!/bin/bash

# ============================================
# Twitter Single Tweet Downloader
# ============================================

# Load configuration file
if [ -f "config/twitter.conf" ]; then
    source "config/twitter.conf"
fi

# Set default values if config is missing
DOWNLOAD_PATH="${DOWNLOAD_PATH:-downloads/twitter}"
MAX_ZIP_SIZE_MB="${MAX_ZIP_SIZE_MB:-90}"
SPLIT_LARGE_FILES="${SPLIT_LARGE_FILES:-true}"

# Get URL from first argument
URL="$1"

# Create download directory
mkdir -p "$DOWNLOAD_PATH"
cd "$DOWNLOAD_PATH"

# Get metadata without downloading the file
METADATA=$(python3 -m yt_dlp --skip-download --dump-json "$URL" 2>/dev/null)

# Extract tweet information
USERNAME=$(echo "$METADATA" | grep -oP '"uploader":\s*"\K[^"]+' | head -1)
if [ -z "$USERNAME" ]; then
    USERNAME=$(echo "$METADATA" | grep -oP '"channel":\s*"\K[^"]+' | head -1)
fi

# Keep spaces in username as they are (no replacement)
USERNAME=$(echo "$USERNAME" | sed 's/^[[:space:]]*//;s/[[:space:]]*$//')

# Extract tweet date (format: YYYY-MM-DD)
TIMESTAMP=$(echo "$METADATA" | grep -oP '"timestamp":\s*[0-9]+' | grep -oP '[0-9]+')
if [ -n "$TIMESTAMP" ]; then
    TWEET_DATE=$(date -d "@$TIMESTAMP" +'%Y-%m-%d' 2>/dev/null)
else
    TWEET_DATE=$(date +'%Y-%m-%d')
fi

# Extract tweet ID
TWEET_ID=$(echo "$URL" | grep -oP 'status/\K[0-9]+')
if [ -z "$TWEET_ID" ]; then
    TWEET_ID=$(echo "$METADATA" | grep -oP '"id":\s*[0-9]+' | head -1 | grep -oP '[0-9]+')
fi

# Extract description (tweet text)
DESCRIPTION=$(echo "$METADATA" | grep -oP '"description":\s*"\K[^"]+' | head -1)
if [ -z "$DESCRIPTION" ]; then
    DESCRIPTION=$(echo "$METADATA" | grep -oP '"title":\s*"\K[^"]+' | head -1)
fi

# Clean description for filename (remove invalid chars, keep spaces)
DESCRIPTION_CLEAN=$(echo "$DESCRIPTION" | cut -c1-50 | sed 's/[\/\\:*?"<>|]/_/g' | sed 's/^[[:space:]]*//;s/[[:space:]]*$//')

# Extract stats (optional fields)
VIEWS=$(echo "$METADATA" | grep -oP '"view_count":\s*[0-9]+' | grep -oP '[0-9]+')
LIKES=$(echo "$METADATA" | grep -oP '"like_count":\s*[0-9]+' | grep -oP '[0-9]+')
RETWEETS=$(echo "$METADATA" | grep -oP '"retweet_count":\s*[0-9]+' | grep -oP '[0-9]+')
REPLIES=$(echo "$METADATA" | grep -oP '"reply_count":\s*[0-9]+' | grep -oP '[0-9]+')

# Build base filename
BASE_FILENAME="${USERNAME} - ${TWEET_DATE} - ${TWEET_ID}"

# Clean description from filename if it exists (optional)
if [ -n "$DESCRIPTION_CLEAN" ]; then
    BASE_FILENAME_WITH_DESC="${USERNAME} - ${TWEET_DATE} - ${TWEET_ID} - ${DESCRIPTION_CLEAN}"
else
    BASE_FILENAME_WITH_DESC="$BASE_FILENAME"
fi

echo "Processing tweet from: $USERNAME"
echo "Tweet date: $TWEET_DATE"
echo "Tweet ID: $TWEET_ID"
echo "Base filename: $BASE_FILENAME"

# Create temporary directory for this tweet
TEMP_DIR="${BASE_FILENAME}"
mkdir -p "$TEMP_DIR"
cd "$TEMP_DIR"

# Create caption.txt (tweet text)
echo "$DESCRIPTION" > "${BASE_FILENAME}.txt"

# Create info.txt (statistics)
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

# Download media files (images and videos) with proper numbering
echo "Downloading media files from tweet..."

# First, get the list of formats to identify media files
python3 -m yt_dlp --skip-download --dump-json "$URL" 2>/dev/null | jq -r '.thumbnails[]?.url // empty' > thumbnails.txt 2>/dev/null

# Download media files (yt-dlp will handle the actual media)
# We need to download the actual media, not just thumbnails
# For Twitter, the video/photo is downloaded by default with the correct format
python3 -m yt_dlp \
    --retries 10 \
    --fragment-retries 10 \
    --retry-sleep exp=1:60 \
    --sleep-interval 2 \
    --max-sleep-interval 5 \
    --limit-rate 500K \
    --ignore-errors \
    --no-abort-on-error \
    --output "${BASE_FILENAME} - %(playlist_index)02d.%(ext)s" \
    --write-info-json \
    "$URL" 2>/dev/null

# Check if any media file was downloaded
MEDIA_COUNT=$(find . -maxdepth 1 -type f \( -name "*.jpg" -o -name "*.png" -o -name "*.mp4" -o -name "*.webm" \) 2>/dev/null | wc -l)

if [ "$MEDIA_COUNT" -gt 0 ]; then
    echo "Found $MEDIA_COUNT media files"
    
    # Rename media files to include the base filename with numbering
    COUNTER=1
    for file in $(ls -1 *.jpg *.png *.mp4 *.webm 2>/dev/null | sort); do
        EXT="${file##*.}"
        NEW_NAME="${BASE_FILENAME} - ${COUNTER}.${EXT}"
        mv "$file" "$NEW_NAME" 2>/dev/null
        COUNTER=$((COUNTER + 1))
    done
    
    # Go back to download directory and create ZIP
    cd ..
    
    TOTAL_SIZE=$(du -sb "$TEMP_DIR" | cut -f1)
    MAX_SIZE_BYTES=$((MAX_ZIP_SIZE_MB * 1024 * 1024))
    
    if [ "$SPLIT_LARGE_FILES" = "true" ] && [ "$TOTAL_SIZE" -gt "$MAX_SIZE_BYTES" ]; then
        echo "File exceeds ${MAX_ZIP_SIZE_MB}MB, splitting into parts"
        zip -s "${MAX_ZIP_SIZE_MB}m" -r "${BASE_FILENAME}.zip" "$TEMP_DIR"
    else
        zip -r "${BASE_FILENAME}.zip" "$TEMP_DIR"
    fi
    
    # Clean up
    rm -rf "$TEMP_DIR"
    
    echo "SUCCESS: Tweet download completed with media - ${BASE_FILENAME}.zip"
    
else
    # No media files (text-only tweet)
    cd ..
    # For text-only tweets, no ZIP needed, just keep the txt files
    # Move the txt files out of temp directory
    mv "${TEMP_DIR}/${BASE_FILENAME}.txt" . 2>/dev/null
    mv "${TEMP_DIR}/${BASE_FILENAME}(info).txt" . 2>/dev/null
    rm -rf "$TEMP_DIR"
    
    echo "SUCCESS: Text-only tweet downloaded - ${BASE_FILENAME}.txt and ${BASE_FILENAME}(info).txt"
fi

# List downloaded files
ls -la
