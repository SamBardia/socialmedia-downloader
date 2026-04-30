#!/bin/bash

if [ -f "config/soundcloud.conf" ]; then
    source "config/soundcloud.conf"
fi

AUDIO_FORMAT="${AUDIO_FORMAT:-mp3}"
DOWNLOAD_PATH="${DOWNLOAD_PATH:-downloads/soundcloud}"

URL="$1"

mkdir -p "$DOWNLOAD_PATH"
cd "$DOWNLOAD_PATH"

METADATA=$(python3 -m yt_dlp --skip-download --dump-json "$URL" 2>/dev/null)

ARTIST=$(echo "$METADATA" | grep -oP '"artist":\s*"\K[^"]+' | head -1)
if [ -z "$ARTIST" ]; then
    ARTIST=$(echo "$METADATA" | grep -oP '"uploader":\s*"\K[^"]+' | head -1)
fi

ARTIST=$(echo "$ARTIST" | sed 's/\\uff0c/,/g' | sed 's/،/,/g')
ARTIST=$(echo "$ARTIST" | sed 's/[[:space:]]*,[[:space:]]*/ \& /g')
ARTIST=$(echo "$ARTIST" | sed 's/^[[:space:]]*//;s/[[:space:]]*$//')
ARTIST=$(echo "$ARTIST" | sed 's/[\/\\:*?"<>|]/_/g' | sed 's/[[:space:]]/_/g' | sed 's/__*/_/g' | sed 's/^_//;s/_$//')

TITLE=$(echo "$METADATA" | grep -oP '"track":\s*"\K[^"]+' | head -1)
if [ -z "$TITLE" ]; then
    TITLE=$(echo "$METADATA" | grep -oP '"title":\s*"\K[^"]+' | head -1)
fi

TITLE=$(echo "$TITLE" | sed 's/[\/\\:*?"<>|]/_/g' | sed 's/[[:space:]]/_/g' | sed 's/__*/_/g' | sed 's/^_//;s/_$//')

if [[ "$TITLE" == "$ARTIST - "* ]]; then
    TITLE="${TITLE#$ARTIST - }"
fi

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
  --output "$FINAL_FILENAME" "$URL"

if [ $? -eq 0 ]; then
    echo "Single track download completed: $FINAL_FILENAME"
else
    echo "Download failed"
    exit 1
fi
