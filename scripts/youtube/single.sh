#!/bin/bash

# ============================================
# YouTube Single Video Downloader
# With fallback logic for unavailable quality
# ============================================

if [ -f "config/youtube.conf" ]; then
    source "config/youtube.conf"
fi

DOWNLOAD_PATH="${DOWNLOAD_PATH:-downloads}"
MAX_ZIP_SIZE_MB="${MAX_ZIP_SIZE_MB:-90}"
SPLIT_LARGE_FILES="${SPLIT_LARGE_FILES:-true}"

URL="$1"
REQUESTED_QUALITY="$2"
COOKIE_FILE="$3"

if [ -z "$COOKIE_FILE" ] || [ ! -f "$COOKIE_FILE" ]; then
    echo "ERROR: Cookie file not found"
    exit 1
fi

# ============================================
# Helper functions
# ============================================

# Get video title directly (clean, without extra info)
get_video_title() {
    local title
    title=$(python3 -m yt_dlp --cookies "$COOKIE_FILE" --get-title "$URL" 2>/dev/null)
    if [ -z "$title" ]; then
        local metadata
        metadata=$(python3 -m yt_dlp --cookies "$COOKIE_FILE" --skip-download --dump-json "$URL" 2>/dev/null)
        title=$(echo "$metadata" | jq -r '.title // .fulltitle // empty')
    fi
    if [ -z "$title" ]; then
        title="unknown_title"
    fi
    # Clean title for filename
    title=$(echo "$title" | sed 's/[\/\\:*?"<>|]/_/g' | sed 's/[[:space:]]\+/_/g' | sed 's/^_//;s/_$//')
    echo "$title"
}

# Check if a specific quality is available
check_quality() {
    local target_height="$1"
    local format_filter="bestvideo[height<=${target_height}]+bestaudio/best[height<=${target_height}]"
    python3 -m yt_dlp --cookies "$COOKIE_FILE" --simulate --format "$format_filter" "$URL" 2>/dev/null
    return $?
}

# Get best available quality (lower than requested first, then higher)
get_best_available_quality() {
    local requested="$1"
    local requested_num=$(echo "$requested" | sed 's/p//')
    
    # First: try qualities lower than requested (from highest to lowest)
    for ((i=requested_num-1; i>=144; i--)); do
        if check_quality "$i"; then
            echo "${i}p"
            return 0
        fi
    done
    
    # Second: try qualities higher than requested (from lowest to highest)
    for ((i=requested_num+1; i<=1080; i++)); do
        if check_quality "$i"; then
            echo "${i}p"
            return 0
        fi
    done
    
    # Finally: try the requested quality itself
    if check_quality "$requested_num"; then
        echo "${requested_num}p"
        return 0
    fi
    
    echo "none"
}

# Quality mapping for yt-dlp height filter
get_height_filter() {
    local quality=$(echo "$1" | sed 's/p//')
    case "$quality" in
        "144")  echo "bestvideo[height<=144]+bestaudio/best[height<=144]" ;;
        "240")  echo "bestvideo[height<=240]+bestaudio/best[height<=240]" ;;
        "360")  echo "bestvideo[height<=360]+bestaudio/best[height<=360]" ;;
        "480")  echo "bestvideo[height<=480]+bestaudio/best[height<=480]" ;;
        "720")  echo "bestvideo[height<=720]+bestaudio/best[height<=720]" ;;
        "1080") echo "bestvideo[height<=1080]+bestaudio/best[height<=1080]" ;;
        "best") echo "bestvideo+bestaudio/best" ;;
        *)      echo "bestvideo+bestaudio/best" ;;
    esac
}

# ============================================
# Main script
# ============================================

mkdir -p "$DOWNLOAD_PATH"
cd "$DOWNLOAD_PATH"

# Get clean video title
TITLE=$(get_video_title)

# ============================================
# Handle audio only
# ============================================
if [ "$REQUESTED_QUALITY" = "audio" ]; then
    BASE_FILENAME="${TITLE} (AUDIO)"
    FINAL_FILENAME="${BASE_FILENAME}.mp3"
    
    COUNTER=1
    while [ -f "$FINAL_FILENAME" ]; do
        FINAL_FILENAME="${BASE_FILENAME}(${COUNTER}).mp3"
        COUNTER=$((COUNTER + 1))
    done
    
    python3 -m yt_dlp --cookies "$COOKIE_FILE" \
        --use-postprocessor "PoToken" \
        --extract-audio --audio-format mp3 \
        --extractor-args "youtube:player_client=ios" \
        --retries 10 --fragment-retries 10 --retry-sleep exp=1:60 \
        --sleep-interval 3 --max-sleep-interval 10 --limit-rate 500K \
        --ignore-errors --no-abort-on-error \
        --output "$FINAL_FILENAME" "$URL"
    
    echo "SUCCESS: Audio saved as $FINAL_FILENAME"
    exit 0
fi

# ============================================
# Handle best quality
# ============================================
if [ "$REQUESTED_QUALITY" = "best" ]; then
    BASE_FILENAME="${TITLE} (BEST)"
    FINAL_FILENAME="${BASE_FILENAME}.mp4"
    
    COUNTER=1
    while [ -f "$FINAL_FILENAME" ]; do
        FINAL_FILENAME="${BASE_FILENAME}(${COUNTER}).mp4"
        COUNTER=$((COUNTER + 1))
    done
    
    python3 -m yt_dlp --cookies "$COOKIE_FILE" \
        --use-postprocessor "PoToken" \
        --format "bestvideo+bestaudio/best" --merge-output-format mp4 \
        --embed-thumbnail --convert-thumbnails jpg \
        --extractor-args "youtube:player_client=ios" \
        --retries 10 --fragment-retries 10 --retry-sleep exp=1:60 \
        --sleep-interval 3 --max-sleep-interval 10 --limit-rate 500K \
        --ignore-errors --no-abort-on-error \
        --output "$FINAL_FILENAME" "$URL"
    
    echo "SUCCESS: Video saved as $FINAL_FILENAME"
    exit 0
fi

# ============================================
# Handle regular quality request with fallback
# ============================================
REQUESTED_CLEAN=$(echo "$REQUESTED_QUALITY" | sed 's/p//')

# Check if requested quality is available
if ! check_quality "$REQUESTED_CLEAN"; then
    ACTUAL_QUALITY=$(get_best_available_quality "$REQUESTED_CLEAN")
    if [ "$ACTUAL_QUALITY" = "none" ]; then
        echo "ERROR: No available quality found for $URL"
        exit 1
    fi
    echo "WARNING: Requested quality ${REQUESTED_CLEAN}p not available. Using $ACTUAL_QUALITY instead."
    ACTUAL_HEIGHT=$(get_height_filter "$ACTUAL_QUALITY")
    ACTUAL_CLEAN=$(echo "$ACTUAL_QUALITY" | sed 's/p//')
    BASE_FILENAME="${TITLE} (${ACTUAL_QUALITY})"
else
    BASE_FILENAME="${TITLE} (${REQUESTED_CLEAN}p)"
    ACTUAL_HEIGHT=$(get_height_filter "${REQUESTED_CLEAN}p")
    ACTUAL_CLEAN="$REQUESTED_CLEAN"
fi

FINAL_FILENAME="${BASE_FILENAME}.mp4"

# Handle duplicate files
COUNTER=1
while [ -f "$FINAL_FILENAME" ]; do
    FINAL_FILENAME="${BASE_FILENAME}(${COUNTER}).mp4"
    COUNTER=$((COUNTER + 1))
done

echo "Downloading: $FINAL_FILENAME"

# Download video with PO Token and ios client
python3 -m yt_dlp --cookies "$COOKIE_FILE" \
    --use-postprocessor "PoToken" \
    --format "$ACTUAL_HEIGHT" --merge-output-format mp4 \
    --embed-thumbnail --convert-thumbnails jpg \
    --extractor-args "youtube:player_client=ios" \
    --retries 10 --fragment-retries 10 --retry-sleep exp=1:60 \
    --sleep-interval 3 --max-sleep-interval 10 --limit-rate 500K \
    --ignore-errors --no-abort-on-error \
    --output "$FINAL_FILENAME" "$URL"

if [ $? -ne 0 ]; then
    echo "ERROR: Download failed for $URL"
    exit 1
fi

# Check file size and split if needed
FILE_SIZE=$(stat -c%s "$FINAL_FILENAME" 2>/dev/null)
MAX_SIZE_BYTES=$((MAX_ZIP_SIZE_MB * 1024 * 1024))

if [ "$SPLIT_LARGE_FILES" = "true" ] && [ "$FILE_SIZE" -gt "$MAX_SIZE_BYTES" ]; then
    echo "File exceeds ${MAX_ZIP_SIZE_MB}MB, splitting into parts"
    zip -s "${MAX_ZIP_SIZE_MB}m" "${BASE_FILENAME}.zip" "$FINAL_FILENAME"
    rm -f "$FINAL_FILENAME"
    echo "SUCCESS: Video saved as ${BASE_FILENAME}.zip (split parts)"
else
    echo "SUCCESS: Video saved as $FINAL_FILENAME"
fi

ls -la
