#!/bin/bash
# ============================================
# Twitter thread downloader
# Downloads all tweets in a thread (with or without media)
# ============================================

if [ -f "config/twitter.conf" ]; then
    source "config/twitter.conf"
fi

DOWNLOAD_PATH="${DOWNLOAD_PATH:-downloads/twitter}"
URL="$1"

# Extract username from URL
USERNAME=$(echo "$URL" | grep -oP 'x\.com/\K[^/]+')
if [ -z "$USERNAME" ]; then
    USERNAME=$(echo "$URL" | grep -oP 'twitter\.com/\K[^/]+')
fi
if [ -z "$USERNAME" ]; then
    echo "ERROR: Could not extract username from URL"
    exit 1
fi
USERNAME=$(echo "$USERNAME" | tr '[:upper:]' '[:lower:]' | sed 's/[^a-z0-9_]//g')
[ -z "$USERNAME" ] && USERNAME="unknown"

# Extract tweet ID from URL
TWEET_ID=$(echo "$URL" | grep -oP 'status/\K[0-9]+')
if [ -z "$TWEET_ID" ]; then
    echo "ERROR: Could not extract tweet ID from URL"
    exit 1
fi

mkdir -p "$DOWNLOAD_PATH"
cd "$DOWNLOAD_PATH"

# Handle duplicate ZIP files
BASE_NAME="${USERNAME} - ${TWEET_ID} - thread"
FINAL_ZIP_NAME="${BASE_NAME}.zip"
COUNT=1
while [ -f "$FINAL_ZIP_NAME" ]; do
    FINAL_ZIP_NAME="${BASE_NAME}(${COUNT}).zip"
    COUNT=$((COUNT + 1))
done

TEMP_DIR="${FINAL_ZIP_NAME%.zip}"
mkdir -p "$TEMP_DIR"
cd "$TEMP_DIR"

# Get thread tweet IDs
echo "Fetching thread tweets..."
python3 -m yt_dlp --flat-playlist --dump-json "$URL" 2>/dev/null | jq -r '.entries[]?.id' > thread_ids.txt

TOTAL_TWEETS=$(wc -l < thread_ids.txt)
echo "Found $TOTAL_TWEETS tweets in thread"

INDEX=1
while read -r tid; do
    [ -z "$tid" ] && continue
    
    TWEET_URL="https://x.com/${USERNAME}/status/${tid}"
    echo "Processing tweet $INDEX of $TOTAL_TWEETS: $tid"
    
    # Get metadata
    METADATA=$(python3 -m yt_dlp --skip-download --dump-json "$TWEET_URL" 2>/dev/null)
    
    # Check if tweet has media
    HAS_MEDIA=false
    MEDIA_COUNT=$(echo "$METADATA" | jq -r '.thumbnails // empty | length' 2>/dev/null)
    if [ -n "$MEDIA_COUNT" ] && [ "$MEDIA_COUNT" -gt 0 ]; then
        HAS_MEDIA=true
    fi
    
    # Extract tweet text
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
    
    # Create folder for this tweet
    TWEET_FOLDER="${INDEX} - ${USERNAME} - ${TWEET_DATE} - ${tid}"
    mkdir -p "$TWEET_FOLDER"
    cd "$TWEET_FOLDER" || exit 1
    
    # Save tweet text
    echo "$DESCRIPTION" > "text.txt"
    
    # Save metadata
    {
        echo "Tweet ID: $tid"
        echo "Author: $USERNAME"
        echo "Date: $TWEET_DATE"
        echo "Time: $TWEET_TIME"
        echo "URL: $TWEET_URL"
        echo "Has Media: $HAS_MEDIA"
        echo ""
        echo "--- Stats ---"
        echo "Likes: $LIKE_COUNT"
        echo "Reposts: $REPOST_COUNT"
        echo "Replies: $REPLY_COUNT"
        echo "Views: $VIEW_COUNT"
    } > "info.txt"
    
    # Download media if present
    if [ "$HAS_MEDIA" = true ]; then
        python3 -m yt_dlp \
            --retries 10 \
            --fragment-retries 10 \
            --ignore-errors \
            --no-abort-on-error \
            --restrict-filenames \
            --output "media_%(playlist_index)02d.%(ext)s" \
            "$TWEET_URL" 2>/dev/null
        
        # Rename media files sequentially
        MEDIA_COUNTER=1
        for file in $(ls -1 *.mp4 *.jpg *.png *.jpeg *.webm 2>/dev/null | sort); do
            if [ -f "$file" ]; then
                ext="${file##*.}"
                new_name="media_${MEDIA_COUNTER}.${ext}"
                mv "$file" "$new_name" 2>/dev/null
                MEDIA_COUNTER=$((MEDIA_COUNTER + 1))
            fi
        done
    fi
    
    cd ..
    INDEX=$((INDEX + 1))
done < thread_ids.txt

cd ..

# Create final ZIP archive
if [ -d "$TEMP_DIR" ] && [ "$(ls -A "$TEMP_DIR" 2>/dev/null)" ]; then
    zip -r "$FINAL_ZIP_NAME" "$TEMP_DIR"
    rm -rf "$TEMP_DIR"
    echo "SUCCESS: Thread saved as $FINAL_ZIP_NAME"
    ls -la "$FINAL_ZIP_NAME"
else
    echo "ERROR: No tweets were downloaded"
    rm -rf "$TEMP_DIR"
    exit 1
fi
