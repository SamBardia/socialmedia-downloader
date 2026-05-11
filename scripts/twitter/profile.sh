#!/bin/bash
# ============================================
# Twitter profile last N tweets downloader
# Downloads all tweets (with or without media) from a profile
# Fixed: COUNT validation + tweet text extraction
# ============================================

if [ -f "config/twitter.conf" ]; then
    source "config/twitter.conf"
fi

DOWNLOAD_PATH="${DOWNLOAD_PATH:-downloads/twitter}"
URL="$1"
COUNT="${2:-20}"

# ============================================
# Validate COUNT is a number
# ============================================
if ! [[ "$COUNT" =~ ^[0-9]+$ ]]; then
    echo "WARNING: COUNT '$COUNT' is not a number, using default 20"
    COUNT=20
fi

# Limit to 50 tweets maximum
if [ "$COUNT" -gt 50 ]; then
    COUNT=50
fi

# Extract username from URL
USERNAME=$(echo "$URL" | sed -n 's|https://x\.com/\([^/]*\).*|\1|p')
if [ -z "$USERNAME" ]; then
    USERNAME=$(echo "$URL" | sed -n 's|https://twitter\.com/\([^/]*\).*|\1|p')
fi
if [ -z "$USERNAME" ]; then
    echo "ERROR: Could not extract username from URL"
    exit 1
fi
USERNAME=$(echo "$USERNAME" | tr '[:upper:]' '[:lower:]' | sed 's/[^a-z0-9_]//g')

mkdir -p "$DOWNLOAD_PATH"
cd "$DOWNLOAD_PATH"

# Handle duplicate ZIP files
BASE_NAME="${USERNAME} - last ${COUNT} tweets"
FINAL_ZIP_NAME="${BASE_NAME}.zip"
CNT=1
while [ -f "$FINAL_ZIP_NAME" ]; do
    FINAL_ZIP_NAME="${BASE_NAME}(${CNT}).zip"
    CNT=$((CNT + 1))
done

TEMP_DIR="${FINAL_ZIP_NAME%.zip}"
mkdir -p "$TEMP_DIR"
cd "$TEMP_DIR"

# Get list of tweet URLs from profile
echo "Fetching last $COUNT tweets from @$USERNAME..."
python3 -m yt_dlp --flat-playlist --playlist-end "$COUNT" --dump-json "https://x.com/${USERNAME}" 2>/dev/null | jq -r '.entries[]?.url' > tweet_urls.txt

TOTAL_TWEETS=$(wc -l < tweet_urls.txt)
echo "Found $TOTAL_TWEETS tweets"

# Function to extract tweet text properly
extract_tweet_text() {
    local title="$1"
    # Remove "User on X: " or "User / X" patterns
    local text=$(echo "$title" | sed -E 's/^[^:]+:[[:space:]]*//' | sed 's/ \/ X$//')
    # If result is empty or just whitespace, try description
    if [ -z "$(echo "$text" | tr -d '[:space:]')" ]; then
        text="$1"
    fi
    echo "$text"
}

INDEX=1
while read -r tweet_url; do
    [ -z "$tweet_url" ] && continue
    
    # Extract tweet ID
    TWEET_ID=$(echo "$tweet_url" | grep -oP 'status/\K[0-9]+')
    if [ -z "$TWEET_ID" ]; then
        continue
    fi
    
    echo "Processing tweet $INDEX of $TOTAL_TWEETS: $TWEET_ID"
    
    # Get metadata
    METADATA=$(python3 -m yt_dlp --skip-download --dump-json "$tweet_url" 2>/dev/null)
    
    # Check if tweet has media
    HAS_MEDIA=false
    MEDIA_COUNT=$(echo "$METADATA" | jq -r '.thumbnails // empty | length' 2>/dev/null)
    if [ -n "$MEDIA_COUNT" ] && [ "$MEDIA_COUNT" -gt 0 ]; then
        HAS_MEDIA=true
    fi
    
    # Extract tweet text - FIXED
    TITLE_TEXT=$(echo "$METADATA" | jq -r '.title // empty')
    DESCRIPTION_TEXT=$(echo "$METADATA" | jq -r '.description // empty')
    
    if [ -n "$TITLE_TEXT" ] && [ "$TITLE_TEXT" != "null" ]; then
        DESCRIPTION=$(extract_tweet_text "$TITLE_TEXT")
    elif [ -n "$DESCRIPTION_TEXT" ] && [ "$DESCRIPTION_TEXT" != "null" ]; then
        DESCRIPTION="$DESCRIPTION_TEXT"
    else
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
    TWEET_FOLDER="${INDEX} - ${USERNAME} - ${TWEET_DATE} - ${TWEET_ID}"
    mkdir -p "$TWEET_FOLDER"
    cd "$TWEET_FOLDER" || exit 1
    
    # Save tweet text
    echo "$DESCRIPTION" > "text.txt"
    
    # Save metadata
    {
        echo "Tweet ID: $TWEET_ID"
        echo "Author: $USERNAME"
        echo "Date: $TWEET_DATE"
        echo "Time: $TWEET_TIME"
        echo "URL: $tweet_url"
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
            "$tweet_url" 2>/dev/null
        
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
done < tweet_urls.txt

cd ..

# Create final ZIP archive
if [ -d "$TEMP_DIR" ] && [ "$(ls -A "$TEMP_DIR" 2>/dev/null)" ]; then
    zip -r "$FINAL_ZIP_NAME" "$TEMP_DIR"
    rm -rf "$TEMP_DIR"
    echo "SUCCESS: Profile saved as $FINAL_ZIP_NAME"
    ls -la "$FINAL_ZIP_NAME"
else
    echo "ERROR: No tweets were downloaded"
    rm -rf "$TEMP_DIR"
    exit 1
fi
