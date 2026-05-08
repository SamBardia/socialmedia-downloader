#!/bin/bash
# ============================================
# Instagram single post/reel downloader
# ============================================

if [ -f "config/instagram.conf" ]; then
    source "config/instagram.conf"
fi

DOWNLOAD_PATH="${DOWNLOAD_PATH:-downloads}"
URL="$1"

[ -n "$INSTAGRAM_COOKIES" ] && { COOKIE_FILE=$(mktemp); echo "$INSTAGRAM_COOKIES" > "$COOKIE_FILE"; } || { echo "Error: Instagram cookies required"; exit 1; }

mkdir -p "$DOWNLOAD_PATH"
cd "$DOWNLOAD_PATH"

python3 -m yt_dlp --cookies "$COOKIE_FILE" \
    --ignore-errors --no-abort-on-error \
    --retries 5 --fragment-retries 5 \
    --output "%(uploader_id)s - %(title)s.%(ext)s" "$URL" 2>/dev/null

rm -f "$COOKIE_FILE"
echo "SUCCESS: downloaded $(ls -1 | wc -l) file(s)"
ls -la
