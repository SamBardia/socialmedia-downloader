#!/bin/bash
# ============================================
# SoundCloud Album/Playlist Downloader
# Mode 1: Standalone - creates a ZIP file in downloads/soundcloud/
# Mode 2: Called from artist.sh - downloads tracks into a specified directory (no ZIP)
# ============================================

if [ -f "config/soundcloud.conf" ]; then
    source "config/soundcloud.conf"
fi

AUDIO_FORMAT="${AUDIO_FORMAT:-mp3}"
DOWNLOAD_PATH="${DOWNLOAD_PATH:-downloads/soundcloud}"
MAX_ZIP_SIZE_MB="${MAX_ZIP_SIZE_MB:-90}"
SPLIT_LARGE_FILES="${SPLIT_LARGE_FILES:-true}"

URL="$1"
TARGET_DIR="$2"  # Optional: if provided, tracks go here (no ZIP)

# ============================================
# Function to download tracks into a given directory
# ============================================
download_tracks_to_dir() {
    local dest_dir="$1"
    mkdir -p "$dest_dir"
    
    # Extract album name for logging
    local album_name=$(basename "$dest_dir")
    echo "Downloading album: $album_name to $dest_dir"
    
    local temp_dir="${album_name} Album"
    mkdir -p "$temp_dir"
    cd "$temp_dir" || exit 1
    
    # Download all tracks with numbered filenames
    python3 -m yt_dlp --extract-audio --audio-format "$AUDIO_FORMAT" \
        --embed-thumbnail --convert-thumbnails jpg \
        --retries 10 --fragment-retries 10 --retry-sleep exp=1:60 \
        --sleep-interval 3 --max-sleep-interval 10 --limit-rate 500K \
        --ignore-errors --no-abort-on-error \
        --output "%(playlist_index)02d - %(title)s.%(ext)s" \
        "$URL"
    
    # Clean up
    rm -f *.webp 2>/dev/null
    rm -f *.jpg.* 2>/dev/null
    
    # Move files to final destination
    cd ..
    mv "$temp_dir"/* "$dest_dir" 2>/dev/null
    rm -rf "$temp_dir"
}

# ============================================
# Mode 1: Standalone (no TARGET_DIR) -> create ZIP
# ============================================
if [ -z "$TARGET_DIR" ]; then
    # Extract album name from URL
    ALBUM_NAME=$(echo "$URL" | sed -n 's|.*/sets/\([^/?]*\).*|\1|p')
    if [ -z "$ALBUM_NAME" ]; then
        ALBUM_NAME=$(echo "$URL" | sed -n 's|.*/playlists/\([^/?]*\).*|\1|p')
    fi
    if [ -z "$ALBUM_NAME" ]; then
        echo "ERROR: Could not extract album/playlist name"
        exit 1
    fi
    
    # Clean album name
    ALBUM_NAME=$(echo "$ALBUM_NAME" | sed 's/[\/\\:*?"<>|]/_/g' | sed 's/[[:space:]]\+/_/g')
    ALBUM_NAME="$(echo "${ALBUM_NAME:0:1}" | tr '[:lower:]' '[:upper:]')${ALBUM_NAME:1}"
    
    echo "Standalone mode: Downloading album '$ALBUM_NAME'"
    
    mkdir -p "$DOWNLOAD_PATH"
    cd "$DOWNLOAD_PATH" || exit 1
    
    # Create temporary directory for album with desired name
    TEMP_DIR="${ALBUM_NAME} Album"
    mkdir -p "$TEMP_DIR"
    
    # Download tracks into temp directory
    download_tracks_to_dir "$TEMP_DIR"
    
    # Prepare ZIP filename
    BASE_ZIP_NAME="${ALBUM_NAME}.zip"
    FINAL_ZIP_NAME="$BASE_ZIP_NAME"
    COUNT=1
    while [ -f "$FINAL_ZIP_NAME" ]; do
        FINAL_ZIP_NAME="${ALBUM_NAME}(${COUNT}).zip"
        COUNT=$((COUNT + 1))
    done
    
    # Create ZIP archive
    TOTAL_SIZE=$(du -sb "$TEMP_DIR" | cut -f1)
    MAX_SIZE_BYTES=$((MAX_ZIP_SIZE_MB * 1024 * 1024))
    
    if [ "$SPLIT_LARGE_FILES" = "true" ] && [ "$TOTAL_SIZE" -gt "$MAX_SIZE_BYTES" ]; then
        zip -s "${MAX_ZIP_SIZE_MB}m} -r "$FINAL_ZIP_NAME" "$TEMP_DIR"
    else
        zip -r "$FINAL_ZIP_NAME" "$TEMP_DIR"
    fi
    
    rm -rf "$TEMP_DIR"
    echo "SUCCESS: Album saved as $FINAL_ZIP_NAME"
    ls -la "$FINAL_ZIP_NAME"*
    exit 0
fi

# ============================================
# Mode 2: Called from artist.sh (TARGET_DIR provided)
# ============================================
echo "Mode: Downloading album into specified directory: $TARGET_DIR"
download_tracks_to_dir "$TARGET_DIR"
echo "Album download completed."
