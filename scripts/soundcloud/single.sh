#!/bin/bash
# ============================================
# SoundCloud single track downloader
# Fixed: Remove duplicate artist name from title
# ============================================

if [ -f "config/soundcloud.conf" ]; then
    source "config/soundcloud.conf"
fi

AUDIO_FORMAT="${AUDIO_FORMAT:-mp3}"
DOWNLOAD_PATH="${DOWNLOAD_PATH:-downloads/soundcloud}"

URL="$1"

mkdir -p "$DOWNLOAD_PATH"
cd "$DOWNLOAD_PATH"

METADATA=$(python3 -m yt_dlp --skip-download --dump-json "$URL" 2>/dev/null)

ARTIST=$(echo "$METADATA" | jq -r '.artist // .uploader // empty')
if [ -z "$ARTIST" ]; then
    ARTIST="unknown_artist"
fi
ARTIST=$(echo "$ARTIST" | perl -CSD -pe 's/\x{ff0c}/,/g' 2>/dev/null || echo "$ARTIST" | sed 's/，/,/g')
ARTIST=$(echo "$ARTIST" | sed 's/[\/\\:*?"<>|]/_/g')

TITLE=$(echo "$METADATA" | jq -r '.track // .title // empty')
if [ -z "$TITLE" ]; then
    TITLE="unknown_title"
fi

# Remove artist name from title if it appears at the beginning
TITLE=$(echo "$TITLE" | sed "s/^${ARTIST} - //g" | sed "s/^${ARTIST}//g" | sed 's/^ - //g')

TITLE=$(echo "$TITLE" | sed 's/[\/\\:*?"<>|]/_/g')

BASE_FILENAME="${ARTIST} - ${TITLE}"
EXTENSION="$AUDIO_FORMAT"
FINAL_FILENAME="${BASE_FILENAME}.${EXTENSION}"
COUNTER=1
while [ -f "$FINAL_FILENAME" ]; do
    FINAL_FILENAME="${BASE_FILENAME}(${COUNTER}).${EXTENSION}"
    COUNTER=$((COUNTER + 1))
done

python3 -m yt_dlp --extract-audio --audio-format "$AUDIO_FORMAT" \
    --embed-thumbnail --convert-thumbnails jpg \
    --retries 10 --fragment-retries 10 --retry-sleep exp=1:60 \
    --sleep-interval 3 --max-sleep-interval 10 --limit-rate 500K \
    --ignore-errors --no-abort-on-error \
    --output "$FINAL_FILENAME" "$URL"

echo "SUCCESS: $FINAL_FILENAME"
ls -la
