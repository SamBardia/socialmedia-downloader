#!/bin/bash
# ============================================
# Core Downloader - Handles both direct files and platform links
# ============================================

if [ -f "config/common.conf" ]; then
    source "config/common.conf"
fi

DOWNLOAD_BASE="${DOWNLOAD_BASE:-dl}"
MAX_ZIP_SIZE_MB="${MAX_ZIP_SIZE_MB:-90}"
SPLIT_LARGE_FILES="${SPLIT_LARGE_FILES:-true}"

URL="$1"

# Create downloads folder structure
mkdir -p "$DOWNLOAD_BASE"
mkdir -p "$DOWNLOAD_BASE/files"

# Function to download a direct file URL using aria2 (like sandbox)
download_direct_file() {
    local file_url="$1"
    local filename=$(basename "$file_url" | cut -d'?' -f1)
    local target_dir="$DOWNLOAD_BASE"
    local target_file="$target_dir/$filename"
    local temp_dir="tmp_downloads"
    
    mkdir -p "$temp_dir"
    
    echo "Downloading direct file: $filename"
    aria2c --split=2 --max-connection-per-server=2 --dir="$temp_dir" "$file_url"
    
    # Check if download was successful
    if [ ! -f "$temp_dir/$filename" ]; then
        echo "ERROR: Failed to download $filename"
        rm -rf "$temp_dir"
        return 1
    fi
    
    # Move file to target directory
    mv "$temp_dir/$filename" "$target_file"
    rm -rf "$temp_dir"
    
    # Get file size
    local file_size=$(stat -c%s "$target_file" 2>/dev/null || stat -f%z "$target_file" 2>/dev/null)
    local max_size_bytes=$((MAX_ZIP_SIZE_MB * 1024 * 1024))
    
    # If file is large, split it
    if [ "$SPLIT_LARGE_FILES" = "true" ] && [ "$file_size" -gt "$max_size_bytes" ]; then
        echo "File exceeds ${MAX_ZIP_SIZE_MB}MB, splitting into parts"
        local base_name="${filename%.*}"
        local temp_split_dir="$target_dir/temp_split_$$"
        mkdir -p "$temp_split_dir"
        mv "$target_file" "$temp_split_dir/"
        cd "$temp_split_dir"
        zip -s "${MAX_ZIP_SIZE_MB}m" "${base_name}.zip" "$filename"
        rm -f "$filename"
        mv "${base_name}.zip"* "$target_dir/"
        cd - > /dev/null
        rm -rf "$temp_split_dir"
    fi
    
    echo "SUCCESS: Saved to $target_file"
    return 0
}

# Function to detect platform
detect_platform() {
    local url="$1"
    if [[ "$url" == *"soundcloud.com"* ]] || [[ "$url" == *"on.soundcloud.com"* ]] || [[ "$url" == *"snd.sc"* ]]; then
        echo "soundcloud"
    elif [[ "$url" == *"x.com"* ]] || [[ "$url" == *"twitter.com"* ]] || [[ "$url" == *"t.co"* ]]; then
        echo "twitter"
    elif [[ "$url" == *"youtu.be"* ]] || [[ "$url" == *"youtube.com"* ]] || [[ "$url" == *"m.youtube.com"* ]]; then
        echo "youtube"
    elif [[ "$url" == *"instagram.com"* ]] || [[ "$url" == *"instagr.am"* ]] || [[ "$url" == *"ig.me"* ]]; then
        echo "instagram"
    elif [[ "$url" == *"tiktok.com"* ]] || [[ "$url" == *"vm.tiktok.com"* ]] || [[ "$url" == *"vt.tiktok.com"* ]]; then
        echo "tiktok"
    elif [[ "$url" =~ ^https?://[^/]+/.+\.[a-zA-Z0-9]{2,4}(\?.*)?$ ]]; then
        echo "direct"
    else
        echo "unknown"
    fi
}

# Process the URL
echo "========================================="
echo "Processing: $URL"
PLATFORM=$(detect_platform "$URL")
echo "Platform: $PLATFORM"

case "$PLATFORM" in
    direct)
        download_direct_file "$URL"
        ;;
    soundcloud)
        if [[ "$URL" == *"/sets/"* ]]; then
            ./scripts/soundcloud/album.sh "$URL"
        elif [[ "$URL" =~ ^https?://soundcloud\.com/[^/]+/?$ ]]; then
            ./scripts/soundcloud/artist.sh "$URL"
        else
            ./scripts/soundcloud/single.sh "$URL"
        fi
        ;;
    twitter)
        if [[ "$URL" == *"/status/"* ]]; then
            ./scripts/twitter/single.sh "$URL"
        else
            ./scripts/twitter/profile.sh "$URL" "$TWITTER_PROFILE_COUNT"
        fi
        ;;
    youtube)
        echo "⚠️ YouTube download is temporarily disabled. Check back later."
        ;;
    instagram)
        echo "⚠️ Instagram download is temporarily disabled. Check back later."
        ;;
    tiktok)
        ./scripts/tiktok/single.sh "$URL"
        ;;
    *)
        echo "WARNING: Unsupported platform for $URL"
        ;;
esac
