#!/bin/bash
# ============================================
# Create Links.md (English & Persian)
# with direct download links in table format
# Newest files appear at the top
# ============================================

DOWNLOAD_BASE="downloads"
LINKS_FILE="Links.md"
LINKS_FILE_FA="Links.fa.md"

# Helper: convert file path to raw GitHub URL
get_raw_url() {
    local file_path="$1"
    file_path="${file_path#./}"
    # URL encode spaces and special characters (simplified)
    encoded_path=$(echo "$file_path" | sed 's/ /%20/g' | sed 's/(/%28/g' | sed 's/)/%29/g')
    echo "https://github.com/${GITHUB_REPOSITORY}/raw/main/${encoded_path}"
}

# Helper: format file size
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

# Helper: get platform from file path
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

# Helper: get current time in given timezone
get_time() {
    local tz="$1"
    export TZ="$tz"
    date +"%Y-%m-%d %H:%M:%S"
}

# Collect all files with their modification time
files_list=""
while IFS= read -r file; do
    # Skip the link files themselves
    if [[ "$file" == "$LINKS_FILE" ]] || [[ "$file" == "$LINKS_FILE_FA" ]]; then
        continue
    fi
    mtime=$(stat -c %Y "$file" 2>/dev/null || stat -f %m "$file" 2>/dev/null)
    files_list="${files_list}${mtime}:${file}\n"
done < <(find "$DOWNLOAD_BASE" -type f ! -path "*/\.*")

# Sort by modification time (newest first) and process
echo "$files_list" | sort -rn | while IFS=: read -r timestamp file; do
    [ -z "$file" ] && continue
    
    filename=$(basename "$file")
    size=$(stat -c%s "$file" 2>/dev/null || stat -f%z "$file" 2>/dev/null)
    size_fmt=$(format_size "$size")
    platform=$(get_platform "$file")
    
    time_utc=$(get_time "UTC")
    time_tehran=$(get_time "Asia/Tehran")
    
    raw_url=$(get_raw_url "$file")
    
    # Store data in temporary file for later use
    echo "$filename|$platform|$size_fmt|$time_utc|$time_tehran|$raw_url" >> /tmp/links_data.txt
done

# Initialize markdown files with table headers
# English version
cat > "$LINKS_FILE" <<'EOF'
# 📦 Download Links (UTC)

This file contains direct download links for every file in the `downloads/` folder.
All timestamps are in **UTC (Greenwich Mean Time)**.

| # | File | Platform | Size | Published (UTC) | Link |
|---|------|----------|------|----------------|------|
EOF

# Persian version (RTL)
cat > "$LINKS_FILE_FA" <<'EOF'
<div dir="rtl">

# 📦 لینک‌های دانلود (به وقت تهران)

این فایل شامل لینک‌های مستقیم دانلود برای تمام فایل‌های موجود در پوشهٔ `downloads/` است.
همهٔ زمان‌ها بر اساس **منطقهٔ زمانی تهران** تنظیم شده‌اند.

| # | نام فایل | پلتفرم | حجم | زمان انتشار (تهران) | لینک |
|---|----------|--------|------|----------------------|------|
EOF

# Process stored data and add to markdown files
counter=1
if [ -f /tmp/links_data.txt ]; then
    while IFS='|' read -r filename platform size_fmt time_utc time_tehran raw_url; do
        # English table row
        printf "| %d | %s | %s | %s | %s | [Download](%s) |\n" \
            "$counter" "$filename" "$platform" "$size_fmt" "$time_utc" "$raw_url" >> "$LINKS_FILE"
        
        # Persian table row (RTL compatible)
        printf "| %d | %s | %s | %s | %s | [دانلود](%s) |\n" \
            "$counter" "$filename" "$platform" "$size_fmt" "$time_tehran" "$raw_url" >> "$LINKS_FILE_FA"
        
        counter=$((counter + 1))
    done < /tmp/links_data.txt
    rm -f /tmp/links_data.txt
fi

# Close RTL div for Persian file
echo "" >> "$LINKS_FILE_FA"
echo "</div>" >> "$LINKS_FILE_FA"

echo "✅ Links created: $LINKS_FILE and $LINKS_FILE_FA (newest first)"
