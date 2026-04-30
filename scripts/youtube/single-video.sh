#!/bin/bash

# ============================================
# YouTube Single Video Downloader
# With fallback logic for unavailable quality
# ============================================

if [ -f "config/youtube.conf" ]; then
    source "config/youtube.conf"
fi

DOWNLOAD_PATH="${DOWNLOAD_PATH:-downloads/youtube}"
MAX_ZIP_SIZE_MB="${MAX_ZIP_SIZE_MB:-90}"
SPLIT_LARGE_FILES="${SPLIT_LARGE_FILES:-true}"

URL="$1"
REQUESTED_QUALITY="$2"
COOKIE_FILE="$3"

if [ -z "$COOKIE_FILE" ] || [ ! -f "$COOKIE_FILE" ]; then
    echo "ERROR: Cookie file not found"
    exit 1
fi

# Quality order (low to high)
QUALITIES=("144" "240" "360" "480" "720" "1080")

# Quality mapping for yt-dlp height filter
get_height_filter() {
    case "$1" in
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

# Check if format exists
check_format() {
    local quality="$1"
    local height_filter=$(get_height_filter "$quality")
    python3 -m yt_dlp --cookies "$COOKIE_FILE" --simulate --format "$height_filter" "$URL" 2>/dev/null
    return $?
}

# Get best available quality (prioritize lower than requested, then higher)
get_best_available_quality() {
    local requested="$1"
    local requested_index=-1
    
    # Find index of requested quality
    for i in "${!QUALITIES[@]}"; do
        if [[ "${QUALITIES[$i]}" == "$requested" ]]; then
            requested_index=$i
            break
        fi
    done
    
    # If requested quality is not in list, treat as best
    if [ $requested_index -eq -1 ]; then
        echo "best"
        return 0
    fi
    
    # First: try qualities lower than requested (from nearest to lowest)
    if [ $requested_index -gt 0 ]; then
        for ((i=$requested_index-1; i>=0; i--)); do
            if check_format "${QUALITIES[$i]}"; then
                echo "${QUALITIES[$i]}"
                return 0
            fi
        done
    fi
    
    # Second: try qualities higher than requested (from nearest to highest)
    if [ $requested_index -lt $((${#QUALITIES[@]} - 1)) ]; then
        for ((i=$requested_index+1; i<${#QUALITIES[@]}; i++)); do
            if check_format "${QUALITIES[$i]}"; then
                echo "${QUALITIES[$i]}"
                return 0
            fi
        done
    fi
    
    # Finally: try the requested quality itself
    if check_format "$requested"; then
        echo "$requested"
        return 0
    fi
    
    echo "none"
}

# ============================================
# Main script
# ============================================

mkdir -p "$DOWNLOAD_PATH"
cd "$DOWNLOAD_PATH"

# Get video metadata
METADATA=$(python3 -m yt_dlp --cookies "$COOKIE_FILE" --skip-download --dump-json "$URL" 2>/dev/null)

# Extract title (only, no uploader)
TITLE=$(echo "$METADATA" | jq -r '.title // empty')
if [ -z "$TITLE" ]; then
    TITLE=$(echo "$METADATA" | jq -r '.fulltitle // empty')
fi
if [ -z "$TITLE" ]; then
    TITLE="unknown_title"
fi
# Keep Persian characters, replace others
TITLE=$(echo "$TITLE" | sed 's/[^a-zA-Z0-9_\u0600-\u06FF -]//g' | sed 's/[_ ]\+/_/g')

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
        --extract-audio --audio-format mp3 \
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
        --format "bestvideo+bestaudio/best" --merge-output-format mp4 \
        --embed-thumbnail --convert-thumbnails jpg \
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
ACTUAL_QUALITY=$(get_best_available_quality "$REQUESTED_QUALITY")

if [ "$ACTUAL_QUALITY" = "none" ]; then
    echo "ERROR: No available quality found for $URL"
    exit 1
fi

if [ "$ACTUAL_QUALITY" != "$REQUESTED_QUALITY" ]; then
    echo "WARNING: Requested quality $REQUESTED_QUALITY not available. Using ${ACTUAL_QUALITY}p instead."
fi

ACTUAL_HEIGHT=$(get_height_filter "$ACTUAL_QUALITY")
BASE_FILENAME="${TITLE} (${ACTUAL_QUALITY}p)"
FINAL_FILENAME="${BASE_FILENAME}.mp4"

COUNTER=1
while [ -f "$FINAL_FILENAME" ]; do
    FINAL_FILENAME="${BASE_FILENAME}(${COUNTER}).mp4"
    COUNTER=$((COUNTER + 1))
done

# Download video
python3 -m yt_dlp --cookies "$COOKIE_FILE" \
    --format "$ACTUAL_HEIGHT" --merge-output-format mp4 \
    --embed-thumbnail --convert-thumbnails jpg \
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
