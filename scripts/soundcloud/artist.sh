#!/bin/bash
# ============================================
# SoundCloud Full Artist Archive Downloader
# ============================================

if [ -f "config/soundcloud.conf" ]; then
    source "config/soundcloud.conf"
fi

DOWNLOAD_PATH="${DOWNLOAD_PATH:-downloads/soundcloud}"
MAX_ZIP_SIZE_MB="${MAX_ZIP_SIZE_MB:-90}"
SPLIT_LARGE_FILES="${SPLIT_LARGE_FILES:-true}"

URL="$1"

# Clean artist name from URL
ARTIST_URL=$(echo "$URL" | sed 's:/*$::')
ARTIST_NAME=$(basename "$ARTIST_URL")
ARTIST_NAME=$(echo "$ARTIST_NAME" | sed 's/[\/\\:*?"<>|]/_/g' | sed 's/[[:space:]]\+/_/g')
ARTIST_NAME="$(echo "${ARTIST_NAME:0:1}" | tr '[:lower:]' '[:upper:]')${ARTIST_NAME:1}"

echo "Processing Artist: $ARTIST_NAME"

mkdir -p "$DOWNLOAD_PATH"
cd "$DOWNLOAD_PATH" || exit 1

MASTER_DIR="${ARTIST_NAME} Archive"
mkdir -p "$MASTER_DIR"
cd "$MASTER_DIR" || exit 1

# Fetch all content metadata from the artist's profile
echo "Fetching content list from SoundCloud..."
yt-dlp --flat-playlist --dump-json "$ARTIST_URL" > raw_data.json 2>/dev/null

# --- Download Singles ---
echo "Downloading singles..."
mkdir -p "Singles"

# Extract all non-album track URLs
grep -oP '(?<="url": ")[^"]+' raw_data.json | grep -v '/sets/' > single_links.txt

while IFS= read -r LINK; do
    if [ -n "$LINK" ]; then
        echo "  -> Processing single: $LINK"
        # Call single.sh from project root
        (cd ../../.. && ./scripts/soundcloud/single.sh "$LINK")
        # Find the most recently downloaded mp3 file
        NEW_FILE=$(find "../../$DOWNLOAD_PATH" -name "*.mp3" -type f -printf '%T@ %p\n' 2>/dev/null | sort -nr | head -1 | cut -d' ' -f2-)
        if [ -n "$NEW_FILE" ] && [ -f "$NEW_FILE" ]; then
            mv "$NEW_FILE" "Singles/"
        fi
    fi
done < single_links.txt

# --- Download Albums ---
echo "Processing albums..."
mkdir -p "EPs & Albums"

# Extract album URLs and names
grep -oP '(?<="url": ")[^"]+/sets/[^"]+' raw_data.json | sort -u > album_links.txt

while IFS= read -r ALBUM_LINK; do
    if [ -n "$ALBUM_LINK" ]; then
        ALBUM_RAW=$(echo "$ALBUM_LINK" | sed 's|.*/sets/||')
        ALBUM_SAFE=$(echo "$ALBUM_RAW" | sed 's/[\/\\:*?"<>|]/_/g' | sed 's/[[:space:]]\+/_/g')
        ALBUM_SAFE="$(echo "${ALBUM_SAFE:0:1}" | tr '[:lower:]' '[:upper:]')${ALBUM_SAFE:1}"

        echo "  -> Processing album: $ALBUM_SAFE"
        TARGET_ALBUM_DIR="EPs & Albums/${ALBUM_SAFE}"
        mkdir -p "$TARGET_ALBUM_DIR"

        # Call album.sh with the target directory
        (cd ../../.. && ./scripts/soundcloud/album.sh "$ALBUM_LINK" "$TARGET_ALBUM_DIR")
    fi
done < album_links.txt

# Clean up temporary files
rm -f raw_data.json single_links.txt album_links.txt

# --- Go back to download directory and create ZIP ---
cd ..

BASE_ZIP_NAME="${ARTIST_NAME} - Complete_Files.zip"
FINAL_ZIP_NAME="$BASE_ZIP_NAME"
COUNT=1
while [ -f "$FINAL_ZIP_NAME" ]; do
    FINAL_ZIP_NAME="${ARTIST_NAME} - Complete_Files(${COUNT}).zip"
    COUNT=$((COUNT + 1))
done

echo "Creating final archive: $FINAL_ZIP_NAME"
zip -r "$FINAL_ZIP_NAME" "$MASTER_DIR"
rm -rf "$MASTER_DIR"

echo "SUCCESS: Full artist archive saved as $FINAL_ZIP_NAME"
ls -la "$FINAL_ZIP_NAME"
