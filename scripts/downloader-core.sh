#!/bin/bash
# ============================================
# Core Downloader - Handles both direct files and platform links
# ============================================

if [ -f "config/common.conf" ]; then
    source "config/common.conf"
fi

DOWNLOAD_BASE="${DOWNLOAD_BASE:-downloads}"
MAX_ZIP_SIZE_MB="${MAX_ZIP_SIZE_MB:-90}"
SPLIT_LARGE_FILES="${SPLIT_LARGE_FILES:-true}"

URL="$1"

# Create downloads folder structure
mkdir -p "$DOWNLOAD_BASE"
mkdir -p "$DOWNLOAD_BASE/files"

# Function to download a direct file URL
download_direct_file() {
    local file_url="$1"
    local filename=$(basename "$file_url" | cut -d'?' -f1)
    local temp_dir="$DOWNLOAD_BASE/files/temp_$$"
    
    mkdir -p "$temp_dir"
    cd "$temp_dir" || exit 1
    
    echo "Downloading direct file: $filename"
    wget --timeout=30 --tries=3 --progress=dot:giga "$file_url" 2>&1 | \
        awk '/[0-9]+%/ {printf "\rProgress: %s", $0} END {print ""}'
    
    # Check if download was successful
    if [ ! -f "$filename" ]; then
        echo "ERROR: Failed to download $filename"
        cd ../..
        rm -rf "$temp_dir"
        return 1
    fi
    
    # Get file size
    local file_size=$(stat -c%s "$filename" 2>/dev/null || stat -f%z "$filename" 2>/dev/null)
    local max_size_bytes=$((MAX_ZIP_SIZE_MB * 1024 * 1024))
    
    # Move file to downloads/files
    cd ../..
    
    if [ "$SPLIT_LARGE_FILES" = "true" ] && [ "$file_size" -gt "$max_size_bytes" ]; then
        echo "File exceeds ${MAX_ZIP_SIZE_MB}MB, splitting into parts"
        cd "$temp_dir"
        local base_name="${filename%.*}"
        zip -s "${MAX_ZIP_SIZE_MB}m" "${base_name}.zip" "$filename"
        rm -f "$filename"
        mv "${base_name}.zip"* "../../files/"
        cd ../..
    else
        mv "$temp_dir/$filename" "files/$filename"
    fi
    
    rm -rf "$temp_dir"
    echo "SUCCESS: Saved to downloads/files/$filename"
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
    elif [[ "$url" =~ ^https?://[^/]+/[^/]+\.(zip|mp3|mp4|jpg|png|pdf|apk)$ ]] || \
         [[ "$url" =~ ^https?://[^/]+/.*\.[a-zA-Z0-9]{2,4}(\?.*)?$ ]]; then
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
