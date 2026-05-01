#!/bin/bash
# ============================================
# YouTube single video downloader with fallback quality
# ============================================

if [ -f "config/youtube.conf" ]; then
    source "config/youtube.conf"
fi

DOWNLOAD_PATH="${DOWNLOAD_PATH:-downloads/youtube}"
URL="$1"
REQUESTED_QUALITY="${2:-480p}"

# Create temp cookie file from secret (passed via environment)
if [ -n "$YOUTUBE_COOKIES" ]; then
    COOKIE_FILE=$(mktemp)
    echo "$YOUTUBE_COOKIES" > "$COOKIE_FILE"
else
    echo "ERROR: No YouTube cookies provided"
    exit 1
fi

mkdir -p "$DOWNLOAD_PATH"
cd "$DOWNLOAD_PATH"

# Get video title
TITLE=$(python3 -m yt_dlp --cookies "$COOKIE_FILE" --get-title "$URL" 2>/dev/null)
if [ -z "$TITLE" ]; then
    TITLE="unknown_title"
fi
TITLE=$(echo "$TITLE" | sed 's/[\/\\:*?"<>|]/_/g' | sed 's/[[:space:]]\+/_/g')

# Quality fallback logic
QUALITY_NUM=$(echo "$REQUESTED_QUALITY" | sed 's/p//')
if [[ "$REQUESTED_QUALITY" == "best" ]]; then
    FORMAT="bestvideo+bestaudio/best"
    BASE_NAME="${TITLE} (BEST)"
elif [[ "$REQUESTED_QUALITY" == "audio" ]]; then
    FORMAT="bestaudio"
    BASE_NAME="${TITLE} (AUDIO)"
    EXT="mp3"
else
    # Try highest available <= requested, then fallback to best
    for q in 1080 720 480 360 240 144; do
        if [ "$q" -le "$QUALITY_NUM" ]; then
            if python3 -m yt_dlp --cookies "$COOKIE_FILE" --simulate \
                -f "bestvideo[height<=$q]+bestaudio/best[height<=$q]" "$URL" 2>/dev/null; then
                FORMAT="bestvideo[height<=$q]+bestaudio/best[height<=$q]"
                BASE_NAME="${TITLE} (${q}p)"
                break
            fi
        fi
    done
    if [ -z "$FORMAT" ]; then
        FORMAT="bestvideo+bestaudio/best"
        BASE_NAME="${TITLE} (BEST)"
    fi
    EXT="mp4"
fi

FINAL_FILENAME="${BASE_NAME}.${EXT}"
COUNT=1
while [ -f "$FINAL_FILENAME" ]; do
    FINAL_FILENAME="${BASE_NAME}(${COUNT}).${EXT}"
    COUNT=$((COUNT + 1))
done

if [[ "$REQUESTED_QUALITY" == "audio" ]]; then
    python3 -m yt_dlp --cookies "$COOKIE_FILE" \
        --extract-audio --audio-format mp3 \
        --embed-thumbnail --convert-thumbnails jpg \
        --retries 10 --fragment-retries 10 --retry-sleep exp=1:60 \
        --sleep-interval 3 --max-sleep-interval 10 --limit-rate 500K \
        --ignore-errors --no-abort-on-error \
        --output "$FINAL_FILENAME" "$URL"
else
    python3 -m yt_dlp --cookies "$COOKIE_FILE" \
        -f "$FORMAT" --merge-output-format mp4 \
        --embed-thumbnail --convert-thumbnails jpg \
        --retries 10 --fragment-retries 10 --retry-sleep exp=1:60 \
        --sleep-interval 3 --max-sleep-interval 10 --limit-rate 500K \
        --ignore-errors --no-abort-on-error \
        --output "$FINAL_FILENAME" "$URL"
fi

rm -f "$COOKIE_FILE"
echo "SUCCESS: $FINAL_FILENAME"
ls -la
