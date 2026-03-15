#!/bin/bash

# Claude Performance Cache v2.1
# RAM-based caching with ripgrep, fd, parallel processing

CACHE_BASE="/Volumes/ClaudeCache"
PROJECT_ROOT="$(pwd)"
PROJECT_HASH=$(echo "$PROJECT_ROOT" | md5sum 2>/dev/null | cut -c1-8 || echo "$PROJECT_ROOT" | md5 | cut -c1-8)
CACHE_DIR="$CACHE_BASE/cache/projects/$PROJECT_HASH"
CACHE_INDEX="$CACHE_DIR/index.json"
CACHE_TIMEOUT=3600
CACHE_ENABLED=false

RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m'

# Create or verify persistent RAM disk on macOS
create_or_verify_ramdisk() {
    if [[ "$OSTYPE" == "darwin"* ]]; then
        if [ -d "$CACHE_BASE" ]; then
            echo -e "${GREEN}Using existing RAM disk at $CACHE_BASE${NC}"
        else
            echo -e "${YELLOW}Creating 2GB RAM disk at $CACHE_BASE...${NC}"
            local dev
            dev=$(hdiutil attach -nobrowse -nomount ram://4194304 2>/dev/null)
            if [ -n "$dev" ]; then
                diskutil erasevolume HFS+ 'ClaudeCache' $dev >/dev/null 2>&1
                if [ -d "$CACHE_BASE" ]; then
                    echo -e "${GREEN}RAM disk created at $CACHE_BASE${NC}"
                    mkdir -p "$CACHE_BASE/cache/projects"
                else
                    echo -e "${RED}diskutil erasevolume failed${NC}"
                    hdiutil detach $dev 2>/dev/null
                fi
            else
                echo -e "${RED}hdiutil attach failed${NC}"
            fi
        fi
    fi
}

init_cache() {
    create_or_verify_ramdisk
    if [ -d "$CACHE_DIR" ]; then
        echo -e "${YELLOW}Using existing cache for project: $(basename "$PROJECT_ROOT")${NC}"
        echo -e "${YELLOW}  Cache location: $CACHE_DIR${NC}"
    else
        mkdir -p "$CACHE_DIR"/{files,search,metadata}
        echo "{}" > "$CACHE_INDEX"
        echo "$PROJECT_ROOT" > "$CACHE_DIR/metadata/project_path.txt"
        echo -e "${GREEN}Cache initialized for project: $(basename "$PROJECT_ROOT")${NC}"
        echo -e "${GREEN}  Cache location: $CACHE_DIR${NC}"
    fi
    precache_files
}

precache_files() {
    echo -e "${YELLOW}Pre-caching project files...${NC}"
    find "$PROJECT_ROOT" -type f -name "*.js" ! -path "*/node_modules/*" ! -path "*/.git/*" \
        -exec bash -c 'cp "$1" "'$CACHE_DIR'/files/$(echo "$1" | sed "s|/|_|g")"' _ {} \; 2>/dev/null &
    find "$PROJECT_ROOT" -type f -name "*.json" ! -path "*/node_modules/*" ! -path "*/.git/*" \
        -exec bash -c 'cp "$1" "'$CACHE_DIR'/files/$(echo "$1" | sed "s|/|_|g")"' _ {} \; 2>/dev/null &
    find "$PROJECT_ROOT" -type f \( -name "*.html" -o -name "*.css" \) ! -path "*/node_modules/*" \
        -exec bash -c 'cp "$1" "'$CACHE_DIR'/files/$(echo "$1" | sed "s|/|_|g")"' _ {} \; 2>/dev/null &
    find "$PROJECT_ROOT" -type f -name "*.md" ! -path "*/node_modules/*" \
        -exec bash -c 'cp "$1" "'$CACHE_DIR'/files/$(echo "$1" | sed "s|/|_|g")"' _ {} \; 2>/dev/null &
    wait
    if command -v rg &> /dev/null; then
        rg --files --no-ignore-vcs --hidden "$PROJECT_ROOT" 2>/dev/null | \
            grep -v node_modules | grep -v .git > "$CACHE_DIR/metadata/file_list.txt"
    else
        find "$PROJECT_ROOT" -type f ! -path "*/node_modules/*" ! -path "*/.git/*" \
            > "$CACHE_DIR/metadata/file_list.txt"
    fi
    echo -e "${GREEN}Pre-cached $(ls -1 "$CACHE_DIR/files" | wc -l) files${NC}"
}

cached_read() {
    local file_path="$1"
    local cache_key=$(echo "$file_path" | sed 's|/|_|g')
    local cached_file="$CACHE_DIR/files/$cache_key"
    if [ ! -f "$cached_file" ] || [ "$file_path" -nt "$cached_file" ]; then
        cp "$file_path" "$cached_file" 2>/dev/null
    fi
    if [ -f "$cached_file" ]; then cat "$cached_file"; else cat "$file_path"; fi
}

cached_search() {
    local pattern="$1"
    local search_hash=$(echo "$pattern" | md5sum | cut -d' ' -f1 2>/dev/null || echo "$pattern" | md5 | cut -d' ' -f1)
    local cached_result="$CACHE_DIR/search/$search_hash"
    mkdir -p "$CACHE_DIR/search" 2>/dev/null
    if [ -f "$cached_result" ]; then
        local cache_age=$(($(date +%s) - $(stat -f %m "$cached_result" 2>/dev/null || stat -c %Y "$cached_result" 2>/dev/null)))
        if [ $cache_age -lt $CACHE_TIMEOUT ]; then cat "$cached_result"; return 0; fi
    fi
    if command -v rg &> /dev/null; then
        rg --threads=$(nproc 2>/dev/null || sysctl -n hw.ncpu 2>/dev/null || echo 4) \
           --max-columns=150 --max-depth=10 --no-ignore-vcs \
           "$pattern" "$PROJECT_ROOT" 2>/dev/null | tee "$cached_result"
    else
        grep -r "$pattern" "$PROJECT_ROOT" --exclude-dir=node_modules --exclude-dir=.git | tee "$cached_result"
    fi
}

fast_find() {
    local pattern="$1"
    if command -v fd &> /dev/null; then
        fd --threads=$(nproc 2>/dev/null || sysctl -n hw.ncpu 2>/dev/null || echo 4) \
           --hidden --no-ignore-vcs --exclude node_modules --exclude .git \
           "$pattern" "$PROJECT_ROOT"
    else
        find "$PROJECT_ROOT" -name "*$pattern*" ! -path "*/node_modules/*" ! -path "*/.git/*"
    fi
}

clear_cache() {
    if [ -d "$CACHE_DIR" ]; then rm -rf "$CACHE_DIR"; echo -e "${GREEN}Cache cleared${NC}"
    else echo -e "${YELLOW}No cache to clear${NC}"; fi
}

cache_stats() {
    if [ ! -d "$CACHE_DIR" ]; then echo -e "${RED}Cache not initialized${NC}"; return 1; fi
    echo -e "${GREEN}Cache Statistics:${NC}"
    echo "  Location: $CACHE_DIR"
    echo "  Cached files: $(ls -1 "$CACHE_DIR/files" 2>/dev/null | wc -l)"
    echo "  Cached searches: $(ls -1 "$CACHE_DIR/search" 2>/dev/null | wc -l)"
    echo "  Total size: $(du -sh "$CACHE_DIR" 2>/dev/null | cut -f1)"
}

export -f cached_read cached_search fast_find
export CACHE_DIR CACHE_ENABLED

case "$1" in
    start) init_cache; CACHE_ENABLED=true; echo -e "${GREEN}Cache system started${NC}" ;;
    stop) clear_cache; CACHE_ENABLED=false ;;
    clear) clear_cache ;;
    stats) cache_stats ;;
    read) [ -z "$2" ] && { echo "Usage: $0 read <file_path>"; exit 1; }; cached_read "$2" ;;
    search) [ -z "$2" ] && { echo "Usage: $0 search <pattern>"; exit 1; }; cached_search "$2" ;;
    find) [ -z "$2" ] && { echo "Usage: $0 find <pattern>"; exit 1; }; fast_find "$2" ;;
    *) echo "Claude Performance Cache v2.1"; echo "Usage: $0 {start|stop|clear|stats|read|search|find}"; exit 1 ;;
esac
