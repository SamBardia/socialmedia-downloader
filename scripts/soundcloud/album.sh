#!/bin/bash
# ============================================
# SoundCloud album/playlist downloader with fallback
# ============================================

if [ -f "config/soundcloud.conf" ]; then
    source "config/soundcloud.conf"
fi

AUDIO_FORMAT="${AUDIO_FORMAT:-mp3}"
DOWNLOAD_PATH="${DOWNLOAD_PATH:-downloads/soundcloud}"
MAX_ZIP_SIZE_MB="${MAX_ZIP_SIZE_MB:-90}"
SPLIT_LARGE_FILES="${SPLIT_LARGE_FILES:-true}"

URL="$1"

COLLECTION_NAME=$(echo "$URL" | sed -n 's|.*/sets/\([^/?]*\).*|\1|p')
if [ -z "$COLLECTION_NAME" ]; then
    COLLECTION_NAME=$(echo "$URL" | sed -n 's|.*/playlists/\([^/?]*\).*|\1|p')
fi
if [ -z "$COLLECTION_NAME" ]; then
    echo "ERROR: Could not extract collection name"
    exit 1
fi

COLLECTION_NAME=$(echo "$COLLECTION_NAME" | sed 's/[\/\\:*?"<>|]/_/g' | sed 's/[[:space:]]\+/_/g')
COLLECTION_NAME="$(echo "${COLLECTION_NAME:0:1}" | tr '[:lower:]' '[:upper:]')${COLLECTION_NAME:1}"

mkdir -p "$DOWNLOAD_PATH"
cd "$DOWNLOAD_PATH"

BASE_ZIP_NAME="${COLLECTION_NAME}.zip"
FINAL_ZIP_NAME="$BASE_ZIP_NAME"
COUNT=1
while [ -f "$FINAL_ZIP_NAME" ]; do
    FINAL_ZIP_NAME="${COLLECTION_NAME}(${COUNT}).zip"
    COUNT=$((COUNT + 1))
done

TEMP_DIR="temp_${COLLECTION_NAME}"
mkdir -p "$TEMP_DIR"
cd "$TEMP_DIR"

# ============================================
# Try standard download
# ============================================
python3 -m yt_dlp --skip-download --write-thumbnail --convert-thumbnails jpg \
    --output "${COLLECTION_NAME}_cover" "$URL" 2>/dev/null

python3 -m yt_dlp --extract-audio --audio-format "$AUDIO_FORMAT" \
    --embed-thumbnail --convert-thumbnails jpg \
    --retries 10 --fragment-retries 10 --retry-sleep exp=1:60 \
    --sleep-interval 3 --max-sleep-interval 10 --limit-rate 500K \
    --ignore-errors --no-abort-on-error \
    --output "%(playlist_index)02d - %(artist)s - %(track)s.%(ext)s" "$URL"

# Check if downloaded MP3 files exist and have valid filenames
if [ -n "$(find . -maxdepth 1 -name '*.mp3' -print -quit 2>/dev/null)" ] && \
   [ -z "$(find . -maxdepth 1 -name '*\n*' -print -quit 2>/dev/null)" ]; then
    # Standard download succeeded
    cd ..
    TOTAL_SIZE=$(du -sb "$TEMP_DIR" | cut -f1)
    MAX_SIZE_BYTES=$((MAX_ZIP_SIZE_MB * 1024 * 1024))

    if [ "$SPLIT_LARGE_FILES" = "true" ] && [ "$TOTAL_SIZE" -gt "$MAX_SIZE_BYTES" ]; then
        zip -s "${MAX_ZIP_SIZE_MB}m" -r "$FINAL_ZIP_NAME" "$TEMP_DIR"
    else
        zip -r "$FINAL_ZIP_NAME" "$TEMP_DIR"
    fi
    rm -rf "$TEMP_DIR"
    echo "SUCCESS: $FINAL_ZIP_NAME"
    ls -la "$FINAL_ZIP_NAME"*
    exit 0
fi

# ============================================
# Fallback: extract track URLs and provide text file
# ============================================
echo "Standard download failed. Generating fallback text file with track URLs..."

TRACKS_FILE="tracks.txt"
python3 -m yt_dlp --flat-playlist --print "%(url)s" "$URL" 2>/dev/null > "$TRACKS_FILE"

# If the above didn't work, try alternative method
if [ ! -s "$TRACKS_FILE" ]; then
    python3 -m yt_dlp --flat-playlist --print "url" "$URL" 2>/dev/null > "$TRACKS_FILE"
fi

if [ -s "$TRACKS_FILE" ]; then
    cd ..
    zip -j "$FINAL_ZIP_NAME" "$TEMP_DIR/$TRACKS_FILE"
    rm -rf "$TEMP_DIR"
    echo "SUCCESS (Fallback): $FINAL_ZIP_NAME contains $TRACKS_FILE with track URLs"
    ls -la "$FINAL_ZIP_NAME"*
else
    echo "ERROR: Failed to extract track URLs for fallback"
    rm -rf "$TEMP_DIR"
    exit 1
fi
