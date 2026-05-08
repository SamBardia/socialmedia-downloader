#!/bin/bash
# ============================================
# Instagram story downloader (last 24h)
# ============================================

if [ -f "config/instagram.conf" ]; then
    source "config/instagram.conf"
fi

DOWNLOAD_PATH="${DOWNLOAD_PATH:-downloads/instagram}"
URL="$1"

[ -n "$INSTAGRAM_COOKIES" ] && { COOKIE_FILE=$(mktemp); echo "$INSTAGRAM_COOKIES" > "$COOKIE_FILE"; } || exit 1

mkdir -p "$DOWNLOAD_PATH"
cd "$DOWNLOAD_PATH"

# Story URLs usually contain /stories/username or /story/...
python3 -m yt_dlp --cookies "$COOKIE_FILE" \
    --no-playlist \
    --ignore-errors --no-abort-on-error \
    --retries 5 --fragment-retries 5 \
    --output "story_%(uploader_id)s_%(epoch)s.%(ext)s" "$URL" 2>/dev/null

rm -f "$COOKIE_FILE"
echo "SUCCESS: downloaded stories"
ls -la
