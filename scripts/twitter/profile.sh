#!/bin/bash
# ============================================
# Twitter profile last N tweets downloader
# ============================================

if [ -f "config/twitter.conf" ]; then
    source "config/twitter.conf"
fi

DOWNLOAD_PATH="${DOWNLOAD_PATH:-downloads/twitter}"
URL="$1"

# Expect URL like https://x.com/username
USERNAME=$(echo "$URL" | sed -n 's|https://x\.com/\([^/]*\).*|\1|p')
[ -z "$USERNAME" ] && USERNAME=$(echo "$URL" | sed -n 's|https://twitter\.com/\([^/]*\).*|\1|p')
[ -z "$USERNAME" ] && { echo "ERROR: No username"; exit 1; }
USERNAME=$(echo "$USERNAME" | tr '[:upper:]' '[:lower:]' | sed 's/[^a-z0-9_]//g')

COUNT=${2:-20}   # Number of tweets to fetch (max 20 for reliability)
[ "$COUNT" -gt 50 ] && COUNT=50

mkdir -p "$DOWNLOAD_PATH"
cd "$DOWNLOAD_PATH"

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

# Use gallery-dl for profile because yt-dlp doesn't handle text-only tweets well
# But we want only media tweets, so we still rely on yt-dlp for media detection.
# Simpler: download all tweets via gallery-dl and then filter? Too heavy.
# We'll use yt-dlp's playlist extraction with --flat-playlist and iterate.
# This is a best-effort approach.
python3 -m yt_dlp --flat-playlist --playlist-end "$COUNT" --dump-json "https://x.com/${USERNAME}" 2>/dev/null | jq -r '.entries[]?.url' > tweet_urls.txt

INDEX=1
while read -r tweet_url; do
    [ -z "$tweet_url" ] && continue
    METADATA=$(python3 -m yt_dlp --skip-download --dump-json "$tweet_url" 2>/dev/null)
    HAS_MEDIA=$(echo "$METADATA" | jq -r '.thumbnails // empty | length')
    if [ -n "$HAS_MEDIA" ] && [ "$HAS_MEDIA" -gt 0 ]; then
        TWEET_ID=$(echo "$tweet_url" | grep -oP 'status/\K[0-9]+')
        mkdir -p "tweet_${INDEX}"
        cd "tweet_${INDEX}"
        # Save tweet info
        echo "$METADATA" | jq -r '.description // .title // "No text"' > "text.txt"
        TIMESTAMP=$(echo "$METADATA" | jq -r '.timestamp // empty')
        if [ -n "$TIMESTAMP" ] && [ "$TIMESTAMP" != "null" ]; then
            T_DATE=$(date -d "@$TIMESTAMP" +'%Y-%m-%d')
            T_TIME=$(date -d "@$TIMESTAMP" +'%H:%M:%S')
        else
            T_DATE=$(date +'%Y-%m-%d')
            T_TIME=$(date +'%H:%M:%S')
        fi
        {
            echo "Tweet ID: $TWEET_ID"
            echo "Date: $T_DATE"
            echo "Time: $T_TIME"
            echo "URL: $tweet_url"
        } > "info.txt"
        python3 -m yt_dlp --retries 5 --ignore-errors --no-abort-on-error \
            --restrict-filenames --output "media_%(playlist_index)02d.%(ext)s" "$tweet_url" 2>/dev/null
        # Rename media sequentially
        MCOUNT=1
        for f in $(ls -1 *.jpg *.png *.jpeg *.mp4 *.webm 2>/dev/null | sort); do
            ext="${f##*.}"
            mv "$f" "media_${MCOUNT}.${ext}" 2>/dev/null
            MCOUNT=$((MCOUNT + 1))
        done
        cd ..
    fi
    INDEX=$((INDEX + 1))
done < tweet_urls.txt

cd ..
zip -r "$FINAL_ZIP_NAME" "$TEMP_DIR"
rm -rf "$TEMP_DIR"
echo "SUCCESS: $FINAL_ZIP_NAME"
