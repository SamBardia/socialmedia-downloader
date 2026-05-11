#!/bin/bash
# ============================================
# Create Links.md and Links.fa.md
# New structure: Group by date, append new dates at top, preserve history
# ============================================

DOWNLOAD_BASE="downloads"
LINKS_FILE="Links.md"
LINKS_FILE_FA="Links.fa.md"
CACHE_FILE=".links_cache.txt"

encode_path() {
    local path="$1"
    python3 -c "import urllib.parse, sys; print(urllib.parse.quote(sys.stdin.read().strip()))" <<< "$path"
}

get_blob_url() {
    local file_path="$1"
    file_path=$(printf "%s" "$file_path" | sed 's|^\./||' | tr -d '\n\r')
    local encoded_path=$(encode_path "$file_path")
    echo "https://github.com/${GITHUB_REPOSITORY}/blob/main/${encoded_path}"
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
    blob_url=$(get_blob_url "$file")
    time_utc=$(format_time_utc "$timestamp")
    time_tehran=$(format_time_tehran "$timestamp")
    
    echo "$timestamp|$time_utc|$time_tehran|$filename|$size_fmt|$blob_url" >> "$ALL_FILES"
done < <(find "$DOWNLOAD_BASE" -type f ! -path "*/\.*" 2>/dev/null)

# Update cache
if [ -s "$NEW_CACHE" ]; then
    mv "$NEW_CACHE" "$CACHE_FILE"
fi

# Group by date (using UTC date for grouping to keep both versions aligned)
sort -rn "$ALL_FILES" > "$TEMP_DIR/sorted_files.txt"

declare -A groups
while IFS='|' read -r ts time_utc time_tehran filename size_fmt blob_url; do
    date_key=$(echo "$time_utc" | cut -d' ' -f1)
    if [ -z "${groups[$date_key]}" ]; then
        groups[$date_key]=""
    fi
    groups[$date_key]="${groups[$date_key]}$ts|$time_utc|$time_tehran|$filename|$size_fmt|$blob_url\n"
done < "$TEMP_DIR/sorted_files.txt"

# Create new content for English and Persian
NEW_CONTENT_EN=""
NEW_CONTENT_FA=""

for date_key in $(echo "${!groups[@]}" | tr ' ' '\n' | sort -r); do
    entries="${groups[$date_key]}"
    # Get the first entry to extract the time string
    first_entry=$(echo -e "$entries" | head -1)
    time_utc_first=$(echo "$first_entry" | cut -d'|' -f2)
    time_tehran_first=$(echo "$first_entry" | cut -d'|' -f3)
    
    # Add date header
    NEW_CONTENT_EN="${NEW_CONTENT_EN}### 📅 ${time_utc_first}\n"
    NEW_CONTENT_FA="${NEW_CONTENT_FA}### 📅 ${time_tehran_first}\n"
    
    # Add entries for this date
    echo -e "$entries" | while IFS='|' read -r ts time_utc time_tehran filename size_fmt blob_url; do
        NEW_CONTENT_EN="${NEW_CONTENT_EN}- [${filename}](${blob_url}) (${size_fmt})\n"
        NEW_CONTENT_FA="${NEW_CONTENT_FA}- [${filename}](${blob_url}) (${size_fmt})\n"
    done
    NEW_CONTENT_EN="${NEW_CONTENT_EN}\n"
    NEW_CONTENT_FA="${NEW_CONTENT_FA}\n"
done

# Read existing content (if any)
OLD_CONTENT_EN=""
OLD_CONTENT_FA=""
if [ -f "$LINKS_FILE" ]; then
    # Extract only the links section (after the first two lines of header)
    OLD_CONTENT_EN=$(sed -n '3,$p' "$LINKS_FILE" 2>/dev/null || echo "")
fi
if [ -f "$LINKS_FILE_FA" ]; then
    OLD_CONTENT_FA=$(sed -n '4,$p' "$LINKS_FILE_FA" 2>/dev/null || echo "")
fi

# Merge: new content first, then old content
FINAL_CONTENT_EN=""
FINAL_CONTENT_FA=""

if [ -n "$NEW_CONTENT_EN" ]; then
    FINAL_CONTENT_EN="${NEW_CONTENT_EN}\n${OLD_CONTENT_EN}"
else
    FINAL_CONTENT_EN="${OLD_CONTENT_EN}"
fi

if [ -n "$NEW_CONTENT_FA" ]; then
    FINAL_CONTENT_FA="${NEW_CONTENT_FA}\n${OLD_CONTENT_FA}"
else
    FINAL_CONTENT_FA="${OLD_CONTENT_FA}"
fi

# Write English file
cat > "$LINKS_FILE" <<EOF
# 🔗 Direct Download Links

Click on any link below to start downloading directly.

${FINAL_CONTENT_EN}
EOF

# Write Persian file
cat > "$LINKS_FILE_FA" <<EOF
<div dir="rtl">

# 🔗 لینک‌های دانلود مستقیم

برای دانلود، روی هر لینک کلیک کنید.

${FINAL_CONTENT_FA}
</div>
EOF

rm -rf "$TEMP_DIR"

echo "✅ Links created: $LINKS_FILE and $LINKS_FILE_FA"
