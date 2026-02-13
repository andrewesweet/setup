#!/bin/bash

set -e

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m' # No Color

# Configuration
ZIG_CACHE_DIR="$HOME/.cache/zig/p"
TEMP_DIR="/tmp/zig-dep-download"
BUILD_DIR="$PWD"
MAX_ITERATIONS=10

# Ensure proxy is set (should be set already for px-proxy)
export http_proxy="${http_proxy:-http://127.0.0.1:3128}"
export https_proxy="${https_proxy:-http://127.0.0.1:3128}"

echo -e "${GREEN}Zig Dependency Downloader for Corporate Proxies${NC}"
echo "Proxy: $https_proxy"
echo "Build directory: $BUILD_DIR"
echo "Cache directory: $ZIG_CACHE_DIR"
echo ""

# Create temp directory
mkdir -p "$TEMP_DIR"

# Function to extract URLs from zig build output
extract_failing_urls() {
    local build_output="$1"
    # Extract URLs that failed with 403, 400, or 404
    echo "$build_output" | grep -oP '\.url = "\K[^"]+' || true
}

# Function to download and cache a dependency
download_and_cache() {
    local url="$1"
    local filename=$(basename "$url")
    local temp_file="$TEMP_DIR/$filename"
    
    echo -e "${YELLOW}Downloading: $url${NC}"
    
    # Download with redirect following
    if curl -L -f -o "$temp_file" "$url"; then
        echo -e "${GREEN}✓ Downloaded successfully${NC}"
        
        # Calculate hash using Zig
        echo "Calculating hash..."
        local hash=$(zig fetch --debug-hash "$temp_file" 2>&1 | grep -oP '1220[a-f0-9]{64}' | head -1)
        
        if [ -z "$hash" ]; then
            echo -e "${RED}✗ Failed to calculate hash${NC}"
            return 1
        fi
        
        echo "Hash: $hash"
        
        # Create cache directory
        local cache_dir="$ZIG_CACHE_DIR/$hash"
        mkdir -p "$cache_dir"
        
        # Extract tarball
        echo "Extracting to cache..."
        cd "$cache_dir"
        
        # Handle both .tar.gz and .tgz
        if [[ "$filename" == *.tar.gz ]] || [[ "$filename" == *.tgz ]]; then
            tar xzf "$temp_file"
            
            # GitHub archives have a subdirectory, move contents up
            local subdir=$(ls -d */ 2>/dev/null | head -1)
            if [ -n "$subdir" ]; then
                mv "$subdir"* . 2>/dev/null || true
                mv "$subdir".* . 2>/dev/null || true
                rmdir "$subdir" 2>/dev/null || true
            fi
        else
            echo -e "${RED}✗ Unknown archive format: $filename${NC}"
            cd "$BUILD_DIR"
            return 1
        fi
        
        cd "$BUILD_DIR"
        rm "$temp_file"
        echo -e "${GREEN}✓ Cached successfully${NC}"
        echo ""
        return 0
    else
        echo -e "${RED}✗ Download failed${NC}"
        echo ""
        return 1
    fi
}

# Main loop
iteration=0
while [ $iteration -lt $MAX_ITERATIONS ]; do
    iteration=$((iteration + 1))
    echo -e "${GREEN}=== Build Attempt $iteration/$MAX_ITERATIONS ===${NC}"
    
    # Run zig build and capture output
    build_output=$(zig build -Doptimize=ReleaseFast 2>&1 || true)
    
    # Check if build succeeded
    if echo "$build_output" | grep -q "Build Summary.*succeeded"; then
        echo -e "${GREEN}╔═══════════════════════════════════════╗${NC}"
        echo -e "${GREEN}║   🎉 BUILD SUCCESSFUL! 🎉            ║${NC}"
        echo -e "${GREEN}╚═══════════════════════════════════════╝${NC}"
        echo ""
        echo "Ghostty.app is at: zig-out/Ghostty.app"
        exit 0
    fi
    
    # Extract failing URLs
    failing_urls=$(extract_failing_urls "$build_output")
    
    if [ -z "$failing_urls" ]; then
        # No URL errors, but build still failed - show error
        echo -e "${RED}Build failed with non-URL error:${NC}"
        echo "$build_output" | tail -20
        exit 1
    fi
    
    # Download each failing dependency
    echo "Found $(echo "$failing_urls" | wc -l) failing URLs"
    echo ""
    
    downloaded_any=false
    while IFS= read -r url; do
        if [ -n "$url" ]; then
            if download_and_cache "$url"; then
                downloaded_any=true
            fi
        fi
    done <<< "$failing_urls"
    
    if [ "$downloaded_any" = false ]; then
        echo -e "${RED}Failed to download any dependencies${NC}"
        echo "Last build output:"
        echo "$build_output"
        exit 1
    fi
    
    echo -e "${YELLOW}Retrying build...${NC}"
    echo ""
done

echo -e "${RED}Maximum iterations reached without successful build${NC}"
exit 1
