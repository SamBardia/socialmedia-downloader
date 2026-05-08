#!/bin/bash
# ============================================
# SoundCloud Full Artist Archive Downloader - Fixed
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
ARTIST_USERNAME=$(basename "$ARTIST_URL")
ARTIST_USERNAME=$(echo "$ARTIST_USERNAME" | sed 's/[\/\\:*?"<>|]/_/g' | sed 's/[[:space:]]\+/_/g')

echo "Processing Artist: $ARTIST_USERNAME"

mkdir -p "$DOWNLOAD_PATH"
cd "$DOWNLOAD_PATH" || exit 1

# Create the master directory (will be zipped)
MASTER_DIR="${ARTIST_USERNAME}"
rm -rf "$MASTER_DIR"  # Clean previous run
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
        # Download the track into the Singles folder
        (cd ../../.. && ./scripts/soundcloud/single.sh "$LINK")
        # Find the most recently downloaded mp3 file
        NEW_FILE=$(find "../../" -name "*.mp3" -type f -printf '%T@ %p\n' 2>/dev/null | sort -nr | head -1 | cut -d' ' -f2-)
        if [ -n "$NEW_FILE" ] && [ -f "$NEW_FILE" ]; then
            mv "$NEW_FILE" "Singles/"
        fi
    fi
done < single_links.txt

# --- Download Albums ---
echo "Processing albums..."
mkdir -p "Albums"

# Extract album URLs and names
grep -oP '(?<="url": ")[^"]+/sets/[^"]+' raw_data.json | sort -u > album_links.txt

while IFS= read -r ALBUM_LINK; do
    if [ -n "$ALBUM_LINK" ]; then
        ALBUM_RAW=$(echo "$ALBUM_LINK" | sed 's|.*/sets/||')
        ALBUM_SAFE=$(echo "$ALBUM_RAW" | sed 's/[\/\\:*?"<>|]/_/g' | sed 's/[[:space:]]\+/_/g')
        echo "  -> Processing album: $ALBUM_SAFE"
        TARGET_ALBUM_DIR="Albums/${ALBUM_SAFE}"
        mkdir -p "$TARGET_ALBUM_DIR"

        # Call album.sh with the target directory
        (cd ../../.. && ./scripts/soundcloud/album.sh "$ALBUM_LINK" "$TARGET_ALBUM_DIR")
    fi
done < album_links.txt

# Clean up temporary files
rm -f raw_data.json single_links.txt album_links.txt

# --- Go back and create ZIP with splitting ---
cd ..

# Remove any existing zip with same name
rm -f "${ARTIST_USERNAME} - Full Archive.zip"*

# Calculate total size and decide split or not
TOTAL_SIZE=$(du -sb "$MASTER_DIR" | cut -f1)
MAX_SIZE_BYTES=$((MAX_ZIP_SIZE_MB * 1024 * 1024))

BASE_ZIP_NAME="${ARTIST_USERNAME} - Full Archive.zip"

if [ "$SPLIT_LARGE_FILES" = "true" ] && [ "$TOTAL_SIZE" -gt "$MAX_SIZE_BYTES" ]; then
    echo "Total size exceeds ${MAX_ZIP_SIZE_MB}MB, splitting ZIP into parts"
    zip -s "${MAX_ZIP_SIZE_MB}m" -r "$BASE_ZIP_NAME" "$MASTER_DIR"
else
    echo "Creating single ZIP archive"
    zip -r "$BASE_ZIP_NAME" "$MASTER_DIR"
fi

# Clean up
rm -rf "$MASTER_DIR"

echo "SUCCESS: Full artist archive saved as ${BASE_ZIP_NAME}"
ls -la "${BASE_ZIP_NAME}"*
