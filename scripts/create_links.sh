#!/bin/bash
# ============================================
# Create Links.md and Links.fa.md
# Group by date, newest first, preserve history
# Using RAW links for direct download
# ============================================

DOWNLOAD_BASE="downloads"
LINKS_FILE="Links.md"
LINKS_FILE_FA="Links.fa.md"
CACHE_FILE=".links_cache.txt"

encode_path() {
    local path="$1"
    python3 -c "import urllib.parse, sys; print(urllib.parse.quote(sys.stdin.read().strip()))" <<< "$path"
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

get_file_time() {
    local file="$1"
    local timestamp=$(stat -c %W "$file" 2>/dev/null)
    if [ "$timestamp" == "0" ] || [ -z "$timestamp" ]; then
        timestamp=$(stat -c %Y "$file")
    fi
    echo "$timestamp"
}

format_time_utc() {
    local timestamp="$1"
    TZ="UTC" date -d "@$timestamp" +"%Y-%m-%d %H:%M UTC" 2>/dev/null || date -r "$timestamp" +"%Y-%m-%d %H:%M UTC"
}

format_time_tehran() {
    local timestamp="$1"
    TZ="Asia/Tehran" date -d "@$timestamp" +"%Y-%m-%d %H:%M تهران" 2>/dev/null || date -r "$timestamp" +"%Y-%m-%d %H:%M تهران"
}

# Load existing cache
declare -A file_cache
if [ -f "$CACHE_FILE" ]; then
    while IFS='|' read -r path timestamp; do
        file_cache["$path"]="$timestamp"
    done < "$CACHE_FILE"
fi

# Collect current files
TEMP_DIR=$(mktemp -d)
NEW_CACHE="$TEMP_DIR/new_cache.txt"
ALL_FILES="$TEMP_DIR/all_files.txt"
> "$ALL_FILES"
> "$NEW_CACHE"

while IFS= read -r file; do
    if [[ "$file" == "$LINKS_FILE" ]] || [[ "$file" == "$LINKS_FILE_FA" ]] || [[ "$file" == "$CACHE_FILE" ]]; then
        continue
    fi
    
    current_time=$(get_file_time "$file")
    
    if [ -n "${file_cache[$file]}" ]; then
        timestamp="${file_cache[$file]}"
        echo "$file|$timestamp" >> "$NEW_CACHE"
    else
        timestamp="$current_time"
        echo "$file|$timestamp" >> "$NEW_CACHE"
    fi
    
    filename=$(basename "$file")
    size=$(stat -c%s "$file" 2>/dev/null || stat -f%z "$file" 2>/dev/null)
    size_fmt=$(format_size "$size")
    raw_url=$(get_raw_url "$file")
    time_utc=$(format_time_utc "$timestamp")
    time_tehran=$(format_time_tehran "$timestamp")
    
    echo "$timestamp|$time_utc|$time_tehran|$filename|$size_fmt|$raw_url" >> "$ALL_FILES"
done < <(find "$DOWNLOAD_BASE" -type f ! -path "*/\.*" 2>/dev/null)

# Update cache
if [ -s "$NEW_CACHE" ]; then
    mv "$NEW_CACHE" "$CACHE_FILE"
fi

# Sort by timestamp (newest first)
sort -rn "$ALL_FILES" > "$TEMP_DIR/sorted_files.txt"

# Build new content lines (using arrays to avoid \n issues)
NEW_CONTENT_EN=()
NEW_CONTENT_FA=()
current_date=""

while IFS='|' read -r ts time_utc time_tehran filename size_fmt raw_url; do
    date_key=$(echo "$time_utc" | cut -d' ' -f1)
    
    if [ "$date_key" != "$current_date" ]; then
        current_date="$date_key"
        NEW_CONTENT_EN+=("### 📅 ${time_utc}")
        NEW_CONTENT_FA+=("### 📅 ${time_tehran}")
    fi
    
    NEW_CONTENT_EN+=("- [${filename}](${raw_url}) (${size_fmt})")
    NEW_CONTENT_FA+=("- [${filename}](${raw_url}) (${size_fmt})")
done < "$TEMP_DIR/sorted_files.txt"

# Read existing content (skip header lines)
OLD_CONTENT_EN=""
OLD_CONTENT_FA=""
if [ -f "$LINKS_FILE" ]; then
    OLD_CONTENT_EN=$(tail -n +3 "$LINKS_FILE" 2>/dev/null | sed '/^$/d' || echo "")
fi
if [ -f "$LINKS_FILE_FA" ]; then
    OLD_CONTENT_FA=$(tail -n +4 "$LINKS_FILE_FA" 2>/dev/null | sed '/^$/d' || echo "")
fi

# Write English file
{
    echo "# 🔗 Direct Download Links"
    echo ""
    echo "Click on any link below to start downloading directly."
    echo ""
    
    if [ ${#NEW_CONTENT_EN[@]} -gt 0 ]; then
        printf "%s\n" "${NEW_CONTENT_EN[@]}"
        echo ""
    fi
    
    if [ -n "$OLD_CONTENT_EN" ]; then
        echo "$OLD_CONTENT_EN"
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
    
    if [ ${#NEW_CONTENT_FA[@]} -gt 0 ]; then
        printf "%s\n" "${NEW_CONTENT_FA[@]}"
        echo ""
    fi
    
    if [ -n "$OLD_CONTENT_FA" ]; then
        echo "$OLD_CONTENT_FA"
    fi
    
    echo "</div>"
} > "$LINKS_FILE_FA"

rm -rf "$TEMP_DIR"

echo "✅ Links created: $LINKS_FILE and $LINKS_FILE_FA (RAW download links)"
