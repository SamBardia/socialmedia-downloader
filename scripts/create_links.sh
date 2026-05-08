#!/bin/bash
# ============================================
# Create Links.md (English & Persian)
# ============================================

DOWNLOAD_BASE="downloads"
LINKS_FILE="Links.md"
LINKS_FILE_FA="Links.fa.md"

encode_path() {
    local path="$1"
    python3 -c "import urllib.parse, sys; print(urllib.parse.quote(sys.stdin.read().strip(), safe='()'))" <<< "$path"
}

get_raw_url() {
    local file_path="$1"
    file_path=$(printf "%s" "$file_path" | sed 's|^\./||' | tr -d '\n\r')
    local encoded_path=$(encode_path "$file_path")
    echo "https://github.com/${GITHUB_REPOSITORY}/raw/main/${encoded_path}"
}

format_size() {
    local size="$1"
    if [ "$size" -lt 1024 ]; then
        echo "${size} B"
    elif [ "$size" -lt 1048576 ]; then
        echo "$(echo "scale=1; $size / 1024" | bc) KB"
    else
        echo "$(echo "scale=1; $size / 1048576" | bc) MB"
    fi
}

get_platform() {
    local file_path="$1"
    if [[ "$file_path" == *"/soundcloud/"* ]]; then
        echo "SoundCloud"
    elif [[ "$file_path" == *"/twitter/"* ]]; then
        echo "Twitter"
    elif [[ "$file_path" == *"/youtube/"* ]]; then
        echo "YouTube"
    elif [[ "$file_path" == *"/instagram/"* ]]; then
        echo "Instagram"
    elif [[ "$file_path" == *"/tiktok/"* ]]; then
        echo "TikTok"
    elif [[ "$file_path" == *"/files/"* ]]; then
        echo "Direct Link"
    else
        echo "Other"
    fi
}

get_time() {
    local tz="$1"
    export TZ="$tz"
    date +"%Y-%m-%d %H:%M:%S"
}

TEMP_DIR=$(mktemp -d)
SORTED_DATA="$TEMP_DIR/sorted_data.txt"
> "$SORTED_DATA"

while IFS= read -r file; do
    if [[ "$file" == "$LINKS_FILE" ]] || [[ "$file" == "$LINKS_FILE_FA" ]]; then
        continue
    fi
    mtime=$(stat -c %Y "$file" 2>/dev/null || stat -f %m "$file" 2>/dev/null)
    if [ -n "$mtime" ]; then
        printf "%d:%s\n" "$mtime" "$file" >> "$TEMP_DIR/all_files.txt"
    fi
done < <(find "$DOWNLOAD_BASE" -type f ! -path "*/\.*" 2>/dev/null)

if [ -f "$TEMP_DIR/all_files.txt" ]; then
    sort -rn "$TEMP_DIR/all_files.txt" | while IFS=: read -r timestamp file; do
        [ -z "$file" ] && continue
        filename=$(basename "$file")
        size=$(stat -c%s "$file" 2>/dev/null || stat -f%z "$file" 2>/dev/null)
        size_fmt=$(format_size "$size")
        platform=$(get_platform "$file")
        time_utc=$(get_time "UTC")
        time_tehran=$(get_time "Asia/Tehran")
        raw_url=$(get_raw_url "$file")
        printf "%s|%s|%s|%s|%s|%s\n" \
            "$filename" "$platform" "$size_fmt" "$time_utc" "$time_tehran" "$raw_url" >> "$SORTED_DATA"
    done
fi

cat > "$LINKS_FILE" <<'EOF'
# 📦 Download Links

This file contains direct download links for every file in the `downloads/` folder.
All timestamps are in **UTC (Greenwich Mean Time)**.

| # | File | Platform | Size | Published (UTC) | Link |
|---|------|----------|------|----------------|------|
EOF

cat > "$LINKS_FILE_FA" <<'EOF'
<div dir="rtl">

# 📦 لینک‌های دانلود

این فایل شامل لینک‌های مستقیم دانلود برای تمام فایل‌های موجود در پوشهٔ `downloads/` است.
همهٔ زمان‌ها بر اساس **منطقهٔ زمانی تهران** تنظیم شده‌اند.

| # | نام فایل | پلتفرم | حجم | زمان انتشار (تهران) | لینک |
|---|----------|--------|------|----------------------|------|
EOF

counter=1
if [ -f "$SORTED_DATA" ]; then
    while IFS='|' read -r filename platform size_fmt time_utc time_tehran raw_url; do
        [ -z "$filename" ] && continue
        [ -z "$raw_url" ] && raw_url="#"
        printf "| %d | %s | %s | %s | %s | [Download](%s) |\n" \
            "$counter" "$filename" "$platform" "$size_fmt" "$time_utc" "$raw_url" >> "$LINKS_FILE"
        printf "| %d | %s | %s | %s | %s | [دانلود](%s) |\n" \
            "$counter" "$filename" "$platform" "$size_fmt" "$time_tehran" "$raw_url" >> "$LINKS_FILE_FA"
        counter=$((counter + 1))
    done < "$SORTED_DATA"
fi

echo "" >> "$LINKS_FILE_FA"
echo "</div>" >> "$LINKS_FILE_FA"

rm -rf "$TEMP_DIR"

echo "✅ Links created: $LINKS_FILE and $LINKS_FILE_FA ($((counter-1)) files, newest first)"
