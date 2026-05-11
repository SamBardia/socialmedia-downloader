#!/bin/bash
# ============================================
# Create Links.md and Links.fa.md
# Simple, clean, no duplicates
# ============================================

DOWNLOAD_BASE="downloads"
LINKS_FILE="Links.md"
LINKS_FILE_FA="Links.fa.md"
CACHE_FILE=".links_cache.txt"

encode_path() {
    python3 -c "import urllib.parse, sys; print(urllib.parse.quote(sys.stdin.read().strip()))" <<< "$1"
}

get_raw_url() {
    local file_path="$1"
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

get_file_time() {
    local file="$1"
    local ts=$(stat -c %W "$file" 2>/dev/null)
    if [ "$ts" == "0" ] || [ -z "$ts" ]; then
        ts=$(stat -c %Y "$file")
    fi
    echo "$ts"
}

format_time_utc() {
    TZ="UTC" date -d "@$1" +"%Y-%m-%d %H:%M UTC" 2>/dev/null || date -r "$1" +"%Y-%m-%d %H:%M UTC"
}

format_time_tehran() {
    TZ="Asia/Tehran" date -d "@$1" +"%Y-%m-%d %H:%M تهران" 2>/dev/null || date -r "$1" +"%Y-%m-%d %H:%M تهران"
}

# Load cache
declare -A cache
if [ -f "$CACHE_FILE" ]; then
    while IFS='|' read -r path ts; do
        cache["$path"]="$ts"
    done < "$CACHE_FILE"
fi

# Collect files
TEMP_DIR=$(mktemp -d)
FILES_DATA="$TEMP_DIR/files.txt"
> "$FILES_DATA"
NEW_CACHE="$TEMP_DIR/new_cache.txt"
> "$NEW_CACHE"

while IFS= read -r file; do
    [[ "$file" == "$LINKS_FILE" || "$file" == "$LINKS_FILE_FA" || "$file" == "$CACHE_FILE" ]] && continue
    
    # دیباگ
    echo "DEBUG: Processing file = $file"
    
    current_ts=$(get_file_time "$file")
    if [ -n "${cache[$file]}" ]; then
        ts="${cache[$file]}"
        echo "$file|$ts" >> "$NEW_CACHE"
    else
        ts="$current_ts"
        echo "$file|$ts" >> "$NEW_CACHE"
    fi
    
    filename=$(basename "$file")
    echo "DEBUG: basename = $filename"
    
    size=$(stat -c%s "$file" 2>/dev/null || stat -f%z "$file" 2>/dev/null)
    size_fmt=$(format_size "$size")
    raw_url=$(get_raw_url "$file")
    time_utc=$(format_time_utc "$ts")
    time_tehran=$(format_time_tehran "$ts")
    
    echo "$ts|$time_utc|$time_tehran|$filename|$size_fmt|$raw_url" >> "$FILES_DATA"
done < <(find "$DOWNLOAD_BASE" -type f 2>/dev/null | sort)

# Update cache
if [ -s "$NEW_CACHE" ]; then
    mv "$NEW_CACHE" "$CACHE_FILE"
fi

# Sort by timestamp (newest first)
sort -t'|' -k1 -rn "$FILES_DATA" > "$TEMP_DIR/sorted.txt"

# Build new content
declare -a NEW_EN=()
declare -a NEW_FA=()
last_date=""

while IFS='|' read -r ts time_utc time_tehran filename size_fmt raw_url; do
    date_utc=$(echo "$time_utc" | cut -d' ' -f1)
    
    if [ "$date_utc" != "$last_date" ]; then
        last_date="$date_utc"
        NEW_EN+=("### 📅 $time_utc")
        NEW_FA+=("### 📅 $time_tehran")
    fi
    
    NEW_EN+=("- [$filename]($raw_url) ($size_fmt)")
    NEW_FA+=("- [$filename]($raw_url) ($size_fmt)")
done < "$TEMP_DIR/sorted.txt"

# Write English file
{
    echo "# 🔗 Direct Download Links"
    echo ""
    echo "Click on any link below to start downloading directly."
    echo ""
    
    if [ ${#NEW_EN[@]} -gt 0 ]; then
        printf "%s\n" "${NEW_EN[@]}"
    else
        echo "No files found."
    fi
} > "$LINKS_FILE"

# Write Persian file
{
    echo "<div dir=\"rtl\">"
    echo ""
    echo "# 🔗 لینک‌های دانلود مستقیم"
    echo ""
    echo "برای دانلود، روی هر لینک کلیک کنید."
    echo ""
    
    if [ ${#NEW_FA[@]} -gt 0 ]; then
        printf "%s\n" "${NEW_FA[@]}"
    else
        echo "هیچ فایلی یافت نشد."
    fi
    
    echo ""
    echo "</div>"
} > "$LINKS_FILE_FA"

rm -rf "$TEMP_DIR"

echo "✅ Links created: $LINKS_FILE and $LINKS_FILE_FA"
