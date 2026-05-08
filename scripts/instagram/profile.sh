#!/bin/bash
# ============================================
# Instagram profile last N posts downloader
# ============================================

if [ -f "config/instagram.conf" ]; then
    source "config/instagram.conf"
fi

DOWNLOAD_PATH="${DOWNLOAD_PATH:-downloads}"
URL="$1"
COUNT="${2:-10}"

[ -n "$INSTAGRAM_COOKIES" ] && { COOKIE_FILE=$(mktemp); echo "$INSTAGRAM_COOKIES" > "$COOKIE_FILE"; } || exit 1

mkdir -p "$DOWNLOAD_PATH"
cd "$DOWNLOAD_PATH"

USERNAME=$(echo "$URL" | sed -n 's|https://www.instagram.com/\([^/?]*\).*|\1|p')
[ -z "$USERNAME" ] && USERNAME="profile"

BASE_NAME="${USERNAME} - last ${COUNT} posts"
FINAL_ZIP_NAME="${BASE_NAME}.zip"
CNT=1
while [ -f "$FINAL_ZIP_NAME" ]; do
    FINAL_ZIP_NAME="${BASE_NAME}(${CNT}).zip"
    CNT=$((CNT + 1))
done

TEMP_DIR="${FINAL_ZIP_NAME%.zip}"
mkdir -p "$TEMP_DIR"
cd "$TEMP_DIR"

python3 -m yt_dlp --cookies "$COOKIE_FILE" \
    --playlist-end "$COUNT" \
    --ignore-errors --no-abort-on-error \
    --retries 5 --fragment-retries 5 \
    --output "%(playlist_index)02d - %(title)s.%(ext)s" "$URL" 2>/dev/null

cd ..
zip -r "$FINAL_ZIP_NAME" "$TEMP_DIR"
rm -rf "$TEMP_DIR"
rm -f "$COOKIE_FILE"
echo "SUCCESS: $FINAL_ZIP_NAME"
