#!/bin/bash
# ============================================
# Create Links.md (English & Persian)
# With persistent file timestamp cache using GitHub Actions cache
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

# Get creation time of file (birth time) if available, fallback to modification time
get_file_time() {
    local file="$1"
    local timestamp=$(stat -c %W "$file" 2>/dev/null)
    if [ "$timestamp" == "0" ] || [ -z "$timestamp" ]; then
        timestamp=$(stat -c %Y "$file")
    fi
    echo "$timestamp"
}

format_time() {
    local timestamp="$1"
    local tz="$2"
    export TZ="$tz"
    date -d "@$timestamp" +"%Y-%m-%d %H:%M:%S" 2>/dev/null || date -r "$timestamp" +"%Y-%m-%d %H:%M:%S"
}

# Load existing cache if present
declare -A file_cache
if [ -f "$CACHE_FILE" ]; then
    while IFS='|' read -r path timestamp; do
        file_cache["$path"]="$timestamp"
    done < "$CACHE_FILE"
fi

# Collect current files and update cache
TEMP_DIR=$(mktemp -d)
SORTED_DATA="$TEMP_DIR/sorted_data.txt"
> "$SORTED_DATA"
NEW_CACHE="$TEMP_DIR/new_cache.txt"

while IFS= read -r file; do
    if [[ "$file" == "$LINKS_FILE" ]] || [[ "$file" == "$LINKS_FILE_FA" ]] || [[ "$file" == "$CACHE_FILE" ]]; then
        continue
    fi
    
    # Get file timestamp (creation or modification)
    current_time=$(get_file_time "$file")
    
    # Use cached timestamp if available, otherwise use current and add to new cache
    if [ -n "${file_cache[$file]}" ]; then
        timestamp="${file_cache[$file]}"
        # Still keep this file in new cache (preserve old timestamp)
        echo "$file|$timestamp" >> "$NEW_CACHE"
    else
        timestamp="$current_time"
        echo "$file|$timestamp" >> "$NEW_CACHE"
    fi
    
    filename=$(basename "$file")
    size=$(stat -c%s "$file" 2>/dev/null || stat -f%z "$file" 2>/dev/null)
    size_fmt=$(format_size "$size")
    platform=$(get_platform "$file")
    time_utc=$(format_time "$timestamp" "UTC")
    time_tehran=$(format_time "$timestamp" "Asia/Tehran")
    blob_url=$(get_blob_url "$file")
    
    printf "%s|%s|%s|%s|%s|%s|%s\n" \
        "$timestamp" "$filename" "$platform" "$size_fmt" "$time_utc" "$time_tehran" "$blob_url" >> "$SORTED_DATA"
done < <(find "$DOWNLOAD_BASE" -type f ! -path "*/\.*" 2>/dev/null)

# Update cache file with current files
if [ -s "$NEW_CACHE" ]; then
    mv "$NEW_CACHE" "$CACHE_FILE"
fi

# Sort by timestamp (newest first)
sort -rn "$SORTED_DATA" > "${SORTED_DATA}.sorted"
mv "${SORTED_DATA}.sorted" "$SORTED_DATA"

# Initialize markdown files
cat > "$LINKS_FILE" <<'EOF'
# 📦 Download Links

> **How to download:** Click the link, then click the **Download** button on the GitHub page to save the file with its original name.
> 
> **Note:** Files that no longer exist in the repository will show "File not found" in the link column.

| # | Status | File | Platform | Size | Published (UTC) | Link |
|---|--------|------|----------|------|----------------|------|
EOF

cat > "$LINKS_FILE_FA" <<'EOF'
<div dir="rtl">

# 📦 لینک‌های دانلود

> **نحوه دانلود:** روی لینک کلیک کنید، سپس در صفحه گیت‌هاب، روی دکمه **Download** کلیک کنید تا فایل با نام اصلی ذخیره شود.
> 
> **نکته:** فایل‌هایی که دیگر در مخزن وجود ندارند، در ستون لینک عبارت "فایل یافت نشد" نشان داده می‌شود.

| # | وضعیت | نام فایل | پلتفرم | حجم | زمان انتشار (تهران) | لینک |
|---|--------|----------|--------|------|----------------------|------|
EOF

counter=1
if [ -f "$SORTED_DATA" ]; then
    while IFS='|' read -r timestamp filename platform size_fmt time_utc time_tehran blob_url; do
        [ -z "$filename" ] && continue
        
        # Check if file still exists
        file_exists=false
        if [ -f "$file" ] 2>/dev/null; then
            file_exists=true
        fi
        
        if [ "$file_exists" = true ]; then
            status_icon="✅"
            status_fa="✅"
            link_btn="<a href=\"$blob_url\" target=\"_blank\">View</a>"
            link_fa="<a href=\"$blob_url\" target=\"_blank\">مشاهده</a>"
        else
            status_icon="❌"
            status_fa="❌"
            link_btn="File not found"
            link_fa="فایل یافت نشد"
        fi
        
        # English table row
        printf "| %d | %s | %s | %s | %s | %s | %s |\n" \
            "$counter" "$status_icon" "$filename" "$platform" "$size_fmt" "$time_utc" "$link_btn" >> "$LINKS_FILE"
        
        # Persian table row
        printf "| %d | %s | %s | %s | %s | %s | %s |\n" \
            "$counter" "$status_fa" "$filename" "$platform" "$size_fmt" "$time_tehran" "$link_fa" >> "$LINKS_FILE_FA"
        
        counter=$((counter + 1))
    done < "$SORTED_DATA"
fi

echo "" >> "$LINKS_FILE_FA"
echo "</div>" >> "$LINKS_FILE_FA"

rm -rf "$TEMP_DIR"

echo "✅ Links created: $LINKS_FILE and $LINKS_FILE_FA ($((counter-1)) files, newest first)"
