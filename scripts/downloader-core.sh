#!/bin/bash

if [ -f "config/common.conf" ]; then
    source "config/common.conf"
fi

DOWNLOAD_BASE="${DOWNLOAD_BASE:-downloads}"
MAX_ZIP_SIZE_MB="${MAX_ZIP_SIZE_MB:-90}"
SPLIT_LARGE_FILES="${SPLIT_LARGE_FILES:-true}"

URL="$1"

mkdir -p "$DOWNLOAD_BASE"
mkdir -p "$DOWNLOAD_BASE/files"

split_large_file() {
    local file_path="$1"
    local max_size_mb="$2"
    
    local file_size=$(stat -c%s "$file_path" 2>/dev/null || stat -f%z "$file_path" 2>/dev/null)
    local max_size_bytes=$((max_size_mb * 1024 * 1024))
    
    if [ "$file_size" -gt "$max_size_bytes" ]; then
        local dir_path=$(dirname "$file_path")
        local base_name=$(basename "$file_path")
        local name_without_ext="${base_name%.*}"
        local temp_dir="$dir_path/split_temp_$$"
        
        echo "File size exceeds ${max_size_mb}MB, splitting into parts"
        
        mkdir -p "$temp_dir"
        cp "$file_path" "$temp_dir/"
        
        cd "$temp_dir"
        zip -s "${max_size_mb}m" "${name_without_ext}.zip" "$base_name"
        rm -f "$base_name"
        mv "${name_without_ext}.zip"* "$dir_path/"
        cd - > /dev/null
        
        rm -rf "$temp_dir"
        rm -f "$file_path"
        
        echo "SUCCESS: File split into parts in $dir_path"
        ls -la "$dir_path/${name_without_ext}.zip"* 2>/dev/null
        return 0
    fi
    return 1
}

download_direct_file() {
    local file_url="$1"
    local filename=$(basename "$file_url" | cut -d'?' -f1)
    local target_dir="$DOWNLOAD_BASE/files"
    local target_file="$target_dir/$filename"
    local temp_dir="tmp_downloads"
    
    mkdir -p "$temp_dir"
    echo "Downloading direct file: $filename"
    aria2c --split=2 --max-connection-per-server=2 --dir="$temp_dir" "$file_url"
    
    if [ ! -f "$temp_dir/$filename" ]; then
        echo "ERROR: Failed to download $filename"
        rm -rf "$temp_dir"
        return 1
    fi
    
    mv "$temp_dir/$filename" "$target_file"
    rm -rf "$temp_dir"
    
    if [ "$SPLIT_LARGE_FILES" = "true" ]; then
        split_large_file "$target_file" "$MAX_ZIP_SIZE_MB"
    fi
    
    echo "SUCCESS: Direct file processing completed"
    return 0
}

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
        echo "YouTube download is temporarily disabled. Check back later."
        ;;
    instagram)
        echo "Instagram download is temporarily disabled. Check back later."
        ;;
    tiktok)
        ./scripts/tiktok/single.sh "$URL"
        ;;
    *)
        echo "WARNING: Unsupported platform for $URL"
        ;;
esac
