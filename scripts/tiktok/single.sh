#!/bin/bash
# ============================================
# TikTok single video downloader
# ============================================

if [ -f "config/tiktok.conf" ]; then
    source "config/tiktok.conf"
fi

DOWNLOAD_PATH="${DOWNLOAD_PATH:-downloads}"
URL="$1"

mkdir -p "$DOWNLOAD_PATH"
cd "$DOWNLOAD_PATH"

python3 -m yt_dlp \
    --ignore-errors --no-abort-on-error \
    --retries 5 --fragment-retries 5 \
    --output "%(uploader_id)s - %(title)s.%(ext)s" "$URL"

echo "SUCCESS: downloaded $(ls -1 | wc -l) file(s)"
ls -la
