#!/bin/bash
# ============================================
# YouTube channel latest videos downloader
# ============================================

if [ -f "config/youtube.conf" ]; then
    source "config/youtube.conf"
fi

DOWNLOAD_PATH="${DOWNLOAD_PATH:-downloads}"
URL="$1"
COUNT="${2:-10}"   # number of latest videos
QUALITY="${3:-480p}"

[ -n "$YOUTUBE_COOKIES" ] && { COOKIE_FILE=$(mktemp); echo "$YOUTUBE_COOKIES" > "$COOKIE_FILE"; } || exit 1

# Extract channel ID or handle
CHANNEL=$(echo "$URL" | sed -n 's|.*youtube\.com/@\([^/?]*\).*|\1|p')
if [ -z "$CHANNEL" ]; then
    CHANNEL=$(echo "$URL" | sed -n 's|.*youtube\.com/channel/\([^/?]*\).*|\1|p')
fi
[ -z "$CHANNEL" ] && { echo "ERROR: Could not parse channel"; exit 1; }

mkdir -p "$DOWNLOAD_PATH"
cd "$DOWNLOAD_PATH"

BASE_NAME="${CHANNEL} - latest ${COUNT} videos"
FINAL_ZIP_NAME="${BASE_NAME}.zip"
CNT=1
while [ -f "$FINAL_ZIP_NAME" ]; do
    FINAL_ZIP_NAME="${BASE_NAME}(${CNT}).zip"
    CNT=$((CNT + 1))
done

TEMP_DIR="${FINAL_ZIP_NAME%.zip}"
mkdir -p "$TEMP_DIR"
cd "$TEMP_DIR"

# Get video URLs using yt-dlp flat-playlist
python3 -m yt_dlp --cookies "$COOKIE_FILE" --flat-playlist --playlist-end "$COUNT" \
    --dump-json "https://www.youtube.com/@${CHANNEL}/videos" 2>/dev/null | jq -r '.entries[]?.url' > video_urls.txt

VID_INDEX=1
while read -r video_url; do
    [ -z "$video_url" ] && continue
    VIDEO_TITLE=$(python3 -m yt_dlp --cookies "$COOKIE_FILE" --get-title "$video_url" 2>/dev/null)
    VIDEO_TITLE=$(echo "$VIDEO_TITLE" | sed 's/[\/\\:*?"<>|]/_/g' | sed 's/[[:space:]]\+/_/g')
    [ -z "$VIDEO_TITLE" ] && VIDEO_TITLE="video_$VID_INDEX"
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
