#!/bin/bash
# ============================================
# Create Links.md and Links.fa.md
# Super simple version - NO encoding
# ============================================

DOWNLOAD_BASE="downloads"
LINKS_FILE="Links.md"
LINKS_FILE_FA="Links.fa.md"

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

# Collect files
TEMP_DIR=$(mktemp -d)
FILES_DATA="$TEMP_DIR/files.txt"
> "$FILES_DATA"

while IFS= read -r file; do
    # Skip link files
    [[ "$file" == "$LINKS_FILE" || "$file" == "$LINKS_FILE_FA" ]] && continue
    
    # Get file info
    ts=$(get_file_time "$file")
    filename=$(basename "$file")
    size=$(stat -c%s "$file" 2>/dev/null || stat -f%z "$file" 2>/dev/null)
    size_fmt=$(format_size "$size")
    time_utc=$(format_time_utc "$ts")
    time_tehran=$(format_time_tehran "$ts")
    
    # Simple raw URL (no encoding, spaces become %20 automatically in markdown)
    raw_url="https://github.com/${GITHUB_REPOSITORY}/raw/main/${file}"
    
    echo "$ts|$time_utc|$time_tehran|$filename|$size_fmt|$raw_url" >> "$FILES_DATA"
done < <(find "$DOWNLOAD_BASE" -type f 2>/dev/null | sort)

# Sort by timestamp (newest first)
sort -t'|' -k1 -rn "$FILES_DATA" > "$TEMP_DIR/sorted.txt"

# Build content
NEW_EN=""
NEW_FA=""
last_date=""

while IFS='|' read -r ts time_utc time_tehran filename size_fmt raw_url; do
    date_utc=$(echo "$time_utc" | cut -d' ' -f1)
    
    if [ "$date_utc" != "$last_date" ]; then
        last_date="$date_utc"
        NEW_EN="${NEW_EN}\n### 📅 ${time_utc}\n"
        NEW_FA="${NEW_FA}\n### 📅 ${time_tehran}\n"
    fi
    
    NEW_EN="${NEW_EN}- [${filename}](${raw_url}) (${size_fmt})\n"
    NEW_FA="${NEW_FA}- [${filename}](${raw_url}) (${size_fmt})\n"
done < "$TEMP_DIR/sorted.txt"

# Write English file
{
    echo "# 🔗 Direct Download Links"
    echo ""
    echo "Click on any link below to start downloading directly."
    echo -e "$NEW_EN"
} > "$LINKS_FILE"

# Write Persian file
{
    echo "<div dir=\"rtl\">"
    echo ""
    echo "# 🔗 لینک‌های دانلود مستقیم"
    echo ""
    echo "برای دانلود، روی هر لینک کلیک کنید."
    echo -e "$NEW_FA"
    echo ""
    echo "</div>"
} > "$LINKS_FILE_FA"

rm -rf "$TEMP_DIR"

echo "✅ Links created: $LINKS_FILE and $LINKS_FILE_FA"
