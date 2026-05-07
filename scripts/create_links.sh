#!/bin/bash
# ============================================
# Create Links.md (English & Persian)
# with direct download links (inline)
# Newest files appear at the top
# ============================================

DOWNLOAD_BASE="downloads"
LINKS_FILE="Links.md"
LINKS_FILE_FA="Links.fa.md"

# Helper: convert file path to raw GitHub URL
get_raw_url() {
    local file_path="$1"
    file_path="${file_path#./}"
    echo "https://github.com/${GITHUB_REPOSITORY}/raw/main/${file_path}"
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

# Helper: get file extension and determine platform
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

# Helper: get current time in a given timezone
get_time() {
    local tz="$1"
    export TZ="$tz"
    date +"%Y-%m-%d %H:%M:%S"
}

# Find all files and sort by modification time (newest first)
find "$DOWNLOAD_BASE" -type f ! -path "*/\.*" | while read -r file; do
    echo "$(stat -c %Y "$file" 2>/dev/null || stat -f %m "$file" 2>/dev/null):$file"
done | sort -rn | cut -d: -f2- > /tmp/files_list.txt

# Initialize markdown files (overwrite)
# English version
cat > "$LINKS_FILE" <<'EOF'
# 📦 Download Links (UTC)

This file contains direct download links for every file in the `downloads/` folder.
All timestamps are in **UTC (Greenwich Mean Time)**.

EOF

# Persian version (RTL)
cat > "$LINKS_FILE_FA" <<'EOF'
<div dir="rtl">

# 📦 لینک‌های دانلود (به وقت تهران)

این فایل شامل لینک‌های مستقیم دانلود برای تمام فایل‌های موجود در پوشهٔ `downloads/` است.
همهٔ زمان‌ها بر اساس **منطقهٔ زمانی تهران** تنظیم شده‌اند.

EOF

# Process each file (newest first)
while read -r file; do
    # Skip the link files themselves
    if [[ "$file" == "$LINKS_FILE" ]] || [[ "$file" == "$LINKS_FILE_FA" ]]; then
        continue
    fi

    filename=$(basename "$file")
    size=$(stat -c%s "$file" 2>/dev/null || stat -f%z "$file" 2>/dev/null)
    size_fmt=$(format_size "$size")
    platform=$(get_platform "$file")
    
    # Times
    time_utc=$(get_time "UTC")
    time_tehran=$(get_time "Asia/Tehran")
    
    raw_url=$(get_raw_url "$file")
    
    # Append to English file (inline link)
    {
        echo "- **${filename}**"
        echo "  - **Platform**: ${platform}"
        echo "  - **Size**: ${size_fmt}"
        echo "  - **Published (UTC)**: ${time_utc}"
        echo "  - **Link**: [${filename}](${raw_url})"
        echo ""
    } >> "$LINKS_FILE"
    
    # Append to Persian file (inline link, RTL)
    {
        echo "- **${filename}**"
        echo "  - **پلتفرم**: ${platform}"
        echo "  - **حجم**: ${size_fmt}"
        echo "  - **زمان انتشار (تهران)**: ${time_tehran}"
        echo "  - **لینک**: [${filename}](${raw_url})"
        echo ""
    } >> "$LINKS_FILE_FA"
    
    echo "Added link for: $filename ($platform)"
done < /tmp/files_list.txt

# Close RTL div for Persian file
echo "</div>" >> "$LINKS_FILE_FA"

rm -f /tmp/files_list.txt
echo "✅ Links created: $LINKS_FILE and $LINKS_FILE_FA (newest first)"
