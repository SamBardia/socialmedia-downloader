#!/bin/bash
# ============================================
# Improved SoundCloud Album/Playlist Downloader
# Downloads album tracks to a specified target directory (no ZIP).
# ============================================

if [ -f "config/soundcloud.conf" ]; then
    source "config/soundcloud.conf"
fi

AUDIO_FORMAT="${AUDIO_FORMAT:-mp3}"
MAX_ZIP_SIZE_MB="${MAX_ZIP_SIZE_MB:-90}"
SPLIT_LARGE_FILES="${SPLIT_LARGE_FILES:-true}"

URL="$1"
TARGET_DIR="$2"  # e.g., 'EPs & Albums/Album Name'

if [ -z "$TARGET_DIR" ]; then
    echo "ERROR: No target directory provided."
    exit 1
fi

mkdir -p "$TARGET_DIR"

ALBUM_NAME=$(basename "$TARGET_DIR")
echo "Downloading Album: $ALBUM_NAME to $TARGET_DIR"

TEMP_DIR="${ALBUM_NAME}_temp"
mkdir -p "$TEMP_DIR"
cd "$TEMP_DIR" || exit 1

# Download all tracks with numbered filenames
python3 -m yt_dlp --extract-audio --audio-format "$AUDIO_FORMAT" \
    --embed-thumbnail --convert-thumbnails jpg \
    --retries 10 --fragment-retries 10 --retry-sleep exp=1:60 \
    --sleep-interval 3 --max-sleep-interval 10 --limit-rate 500K \
    --ignore-errors --no-abort-on-error \
    --output "%(playlist_index)02d - %(title)s.%(ext)s" \
    "$URL"

rm -f *.webp 2>/dev/null
rm -f *.jpg.* 2>/dev/null

# Move files to the final target directory
cd ..
mv "$TEMP_DIR"/* "$TARGET_DIR" 2>/dev/null
rm -rf "$TEMP_DIR"

echo "Album Download Completed: $ALBUM_NAME"
