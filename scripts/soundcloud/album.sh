#!/bin/bash
# ============================================
# SoundCloud album/playlist downloader
# Uses single.sh for each track to avoid yt-dlp bugs
# ============================================

if [ -f "config/soundcloud.conf" ]; then
    source "config/soundcloud.conf"
fi

AUDIO_FORMAT="${AUDIO_FORMAT:-mp3}"
DOWNLOAD_PATH="${DOWNLOAD_PATH:-downloads/soundcloud}"

URL="$1"

# Extract collection name from URL
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

# Create a temporary directory for this album
TEMP_DIR="${COLLECTION_NAME} Album"
mkdir -p "$TEMP_DIR"
cd "$TEMP_DIR"

# Extract all track URLs using flat-playlist
echo "Extracting track URLs..."
python3 -m yt_dlp --flat-playlist --print "%(url)s" "$URL" 2>/dev/null > track_urls.txt

# Show how many tracks found
TRACK_COUNT=$(wc -l < track_urls.txt)
echo "Found $TRACK_COUNT tracks in album"

# Download each track using single.sh
TRACK_NUMBER=1
while read -r TRACK_URL; do
    [ -z "$TRACK_URL" ] && continue
    echo "Downloading track $TRACK_NUMBER of $TRACK_COUNT: $TRACK_URL"
    
    # Download with single.sh
    ../single.sh "$TRACK_URL"
    
    # Rename to add track number prefix
    for file in *.mp3; do
        if [ -f "$file" ] && [ ! -f "${TRACK_NUMBER} - $file" ]; then
            mv "$file" "${TRACK_NUMBER} - $file" 2>/dev/null
        fi
    done
    
    TRACK_NUMBER=$((TRACK_NUMBER + 1))
done < track_urls.txt

cd ..
# Handle duplicate ZIP files
BASE_ZIP_NAME="${COLLECTION_NAME}.zip"
FINAL_ZIP_NAME="$BASE_ZIP_NAME"
COUNT=1
while [ -f "$FINAL_ZIP_NAME" ]; do
    FINAL_ZIP_NAME="${COLLECTION_NAME}(${COUNT}).zip"
    COUNT=$((COUNT + 1))
done

# Create ZIP archive
if [ -d "$TEMP_DIR" ] && [ "$(ls -A "$TEMP_DIR" 2>/dev/null)" ]; then
    zip -r "$FINAL_ZIP_NAME" "$TEMP_DIR"
    rm -rf "$TEMP_DIR"
    echo "SUCCESS: $FINAL_ZIP_NAME"
    ls -la "$FINAL_ZIP_NAME"
else
    echo "ERROR: No files downloaded"
    rm -rf "$TEMP_DIR"
    exit 1
fi
