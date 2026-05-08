#!/bin/bash
# ============================================
# YouTube playlist downloader
# ============================================

if [ -f "config/youtube.conf" ]; then
    source "config/youtube.conf"
fi

DOWNLOAD_PATH="${DOWNLOAD_PATH:-downloads}"
URL="$1"
QUALITY="${2:-480p}"

[ -n "$YOUTUBE_COOKIES" ] && { COOKIE_FILE=$(mktemp); echo "$YOUTUBE_COOKIES" > "$COOKIE_FILE"; } || { echo "No cookies"; exit 1; }

PLAYLIST_ID=$(echo "$URL" | grep -oP '(list=)[^&]+' | cut -d= -f2)
if [ -z "$PLAYLIST_ID" ]; then
    echo "ERROR: Not a playlist URL"
    exit 1
fi

mkdir -p "$DOWNLOAD_PATH"
cd "$DOWNLOAD_PATH"

# Get playlist title from first video metadata
FIRST_VIDEO=$(python3 -m yt_dlp --cookies "$COOKIE_FILE" --flat-playlist --dump-json "$URL" 2>/dev/null | jq -r '.entries[0]?.title')
PLAYLIST_TITLE=$(echo "$FIRST_VIDEO" | sed 's/[\/\\:*?"<>|]/_/g' | sed 's/[[:space:]]\+/_/g')
[ -z "$PLAYLIST_TITLE" ] && PLAYLIST_TITLE="playlist_$PLAYLIST_ID"

BASE_NAME="${PLAYLIST_TITLE} - playlist"
FINAL_ZIP_NAME="${BASE_NAME}.zip"
COUNT=1
while [ -f "$FINAL_ZIP_NAME" ]; do
    FINAL_ZIP_NAME="${BASE_NAME}(${COUNT}).zip"
    COUNT=$((COUNT + 1))
done

TEMP_DIR="${FINAL_ZIP_NAME%.zip}"
mkdir -p "$TEMP_DIR"
cd "$TEMP_DIR"

# Download using yt-dlp's playlist feature
# We loop through entries to apply quality selection per video
python3 -m yt_dlp --cookies "$COOKIE_FILE" --flat-playlist --dump-json "$URL" 2>/dev/null | jq -r '.entries[]?.url' > video_urls.txt

VID_INDEX=1
while read -r video_url; do
    [ -z "$video_url" ] && continue
    VIDEO_TITLE=$(python3 -m yt_dlp --cookies "$COOKIE_FILE" --get-title "$video_url" 2>/dev/null)
    VIDEO_TITLE=$(echo "$VIDEO_TITLE" | sed 's/[\/\\:*?"<>|]/_/g' | sed 's/[[:space:]]\+/_/g')
    QUALITY_NUM=$(echo "$QUALITY" | sed 's/p//')
    if [[ "$QUALITY" == "best" ]]; then
        FORMAT="bestvideo+bestaudio/best"
    elif [[ "$QUALITY" == "audio" ]]; then
        FORMAT="bestaudio"
        EXT="mp3"
    else
        FORMAT="bestvideo[height<=$QUALITY_NUM]+bestaudio/best[height<=$QUALITY_NUM]"
        EXT="mp4"
    fi
    OUTPUT="${VID_INDEX} - ${VIDEO_TITLE}.${EXT:-mp4}"
    if [[ "$QUALITY" == "audio" ]]; then
        python3 -m yt_dlp --cookies "$COOKIE_FILE" \
            --extract-audio --audio-format mp3 \
            --embed-thumbnail --convert-thumbnails jpg \
            --retries 10 --fragment-retries 10 \
            --output "$OUTPUT" "$video_url" 2>/dev/null
    else
        python3 -m yt_dlp --cookies "$COOKIE_FILE" \
            -f "$FORMAT" --merge-output-format mp4 \
            --embed-thumbnail --convert-thumbnails jpg \
            --retries 10 --fragment-retries 10 \
            --output "$OUTPUT" "$video_url" 2>/dev/null
    fi
    VID_INDEX=$((VID_INDEX + 1))
done < video_urls.txt

cd ..
zip -r "$FINAL_ZIP_NAME" "$TEMP_DIR"
rm -rf "$TEMP_DIR"
rm -f "$COOKIE_FILE"
echo "SUCCESS: $FINAL_ZIP_NAME"
