#!/bin/bash
# ============================================
# Create Links.md (English & Persian)
# with direct download links for all files
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

# Helper: get current time in a given timezone (argument: TZ)
get_time() {
    local tz="$1"
    export TZ="$tz"
    date +"%Y-%m-%d %H:%M:%S"
}

# Initialize markdown files (overwrite)
cat > "$LINKS_FILE" <<EOF
# 📦 Download Links (UTC)

This file contains direct download links for every file in the \`downloads/\` folder.
All timestamps are in **UTC (Greenwich Mean Time)**.

| File | Size | Published (UTC) | Link |
|------|------|----------------|------|
EOF

cat > "$LINKS_FILE_FA" <<EOF
# 📦 لینک‌های دانلود (به وقت تهران)

این فایل شامل لینک‌های مستقیم دانلود برای تمام فایل‌های موجود در پوشهٔ \`downloads/\` است.
همهٔ زمان‌ها بر اساس **منطقهٔ زمانی تهران** تنظیم شده‌اند.

| نام فایل | حجم | زمان انتشار (تهران) | لینک |
|----------|------|----------------------|------|
EOF

# Find all files (no skip, including .z01, .z02, etc.)
find "$DOWNLOAD_BASE" -type f | sort | while read -r file; do
    # Skip the link files themselves
    if [[ "$file" == "$LINKS_FILE" ]] || [[ "$file" == "$LINKS_FILE_FA" ]]; then
        continue
    fi

    filename=$(basename "$file")
    size=$(stat -c%s "$file" 2>/dev/null || stat -f%z "$file" 2>/dev/null)
    size_fmt=$(format_size "$size")

    # Times
    time_utc=$(get_time "UTC")
    time_tehran=$(get_time "Asia/Tehran")

    raw_url=$(get_raw_url "$file")

    # Append to English table (UTC)
    printf "| %s | %s | %s | [Download](%s) |\n" \
        "$filename" "$size_fmt" "$time_utc" "$raw_url" >> "$LINKS_FILE"

    # Append to Persian table (Tehran)
    printf "| %s | %s | %s | [دانلود](%s) |\n" \
        "$filename" "$size_fmt" "$time_tehran" "$raw_url" >> "$LINKS_FILE_FA"

    echo "Added link for: $filename"
done

echo "" >> "$LINKS_FILE"
echo "" >> "$LINKS_FILE_FA"
echo "✅ Links created: $LINKS_FILE and $LINKS_FILE_FA"
