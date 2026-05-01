#!/bin/bash
# ============================================
# Twitter thread downloader
# ============================================

if [ -f "config/twitter.conf" ]; then
    source "config/twitter.conf"
fi

DOWNLOAD_PATH="${DOWNLOAD_PATH:-downloads/twitter}"
URL="$1"

USERNAME=$(echo "$URL" | grep -oP 'x\.com/\K[^/]+')
[ -z "$USERNAME" ] && USERNAME=$(echo "$URL" | grep -oP 'twitter\.com/\K[^/]+')
USERNAME=$(echo "$USERNAME" | tr '[:upper:]' '[:lower:]' | sed 's/[^a-z0-9_]//g')
[ -z "$USERNAME" ] && USERNAME="unknown"

TWEET_ID=$(echo "$URL" | grep -oP 'status/\K[0-9]+')
[ -z "$TWEET_ID" ] && { echo "ERROR: No tweet ID"; exit 1; }

mkdir -p "$DOWNLOAD_PATH"
cd "$DOWNLOAD_PATH"

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

# Get list of tweet IDs in the thread using yt-dlp's playlist feature
# This is simplified; in reality you'd need to parse thread structure.
# For robust thread detection you may need to use twitter API or gallery-dl.
# Here we use yt-dlp with `--flat-playlist` to get all entries.
python3 -m yt_dlp --flat-playlist --dump-json "$URL" 2>/dev/null | jq -r '.entries[]?.id' > thread_ids.txt

INDEX=1
while read -r tid; do
    [ -z "$tid" ] && continue
    TWEET_URL="https://x.com/${USERNAME}/status/${tid}"
    METADATA=$(python3 -m yt_dlp --skip-download --dump-json "$TWEET_URL" 2>/dev/null)
    HAS_MEDIA=$(echo "$METADATA" | jq -r '.thumbnails // empty | length')
    if [ -n "$HAS_MEDIA" ] && [ "$HAS_MEDIA" -gt 0 ]; then
        mkdir -p "tweet_${INDEX}"
        cd "tweet_${INDEX}"
        echo "$METADATA" | jq -r '.description // .title // "No text"' > "text.txt"
        python3 -m yt_dlp --retries 5 --ignore-errors --no-abort-on-error \
            --restrict-filenames --output "media_%(playlist_index)02d.%(ext)s" "$TWEET_URL" 2>/dev/null
        # Rename media files inside
        MCOUNT=1
        for f in $(ls -1 *.jpg *.png *.jpeg *.mp4 *.webm 2>/dev/null | sort); do
            ext="${f##*.}"
            mv "$f" "media_${MCOUNT}.${ext}" 2>/dev/null
            MCOUNT=$((MCOUNT + 1))
        done
        cd ..
    fi
    INDEX=$((INDEX + 1))
done < thread_ids.txt

cd ..
zip -r "$FINAL_ZIP_NAME" "$TEMP_DIR"
rm -rf "$TEMP_DIR"
echo "SUCCESS: $FINAL_ZIP_NAME"
