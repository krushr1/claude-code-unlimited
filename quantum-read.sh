#!/bin/bash

# QUANTUM READ - Parallel chunk reading for large files
# Reads massive files by splitting into quantum chunks and reading in parallel

FILE="$1"
MODE="${2:-full}"  # full, search, or smart
SEARCH_TERM="$3"

# Token limit per chunk (stay well under 25k)
MAX_TOKENS_PER_CHUNK=20000
AVG_CHARS_PER_TOKEN=4  # Approximate
MAX_CHARS_PER_CHUNK=$((MAX_TOKENS_PER_CHUNK * AVG_CHARS_PER_TOKEN))
MAX_LINES_PER_CHUNK=800  # Conservative to stay under token limit

# Use existing ClaudeCache RAM disk if mounted, otherwise /tmp
if [ -d "/Volumes/ClaudeCache" ]; then
    CACHE_DIR="/Volumes/ClaudeCache/claude-cache"
else
    CACHE_DIR="/tmp/claude-quantum-cache"
fi
QUANTUM_CACHE="$CACHE_DIR/quantum"
mkdir -p "$QUANTUM_CACHE" 2>/dev/null

# Get file stats
TOTAL_LINES=$(wc -l < "$FILE")
TOTAL_CHARS=$(wc -c < "$FILE")
FILE_HASH=$(md5 -q "$FILE" 2>/dev/null || md5sum "$FILE" | cut -d' ' -f1)
CACHE_KEY="${FILE_HASH}_${MODE}_${SEARCH_TERM}"

echo "QUANTUM READ v2.1"
echo "File: $(basename "$FILE")"
echo "Stats: $TOTAL_LINES lines, $TOTAL_CHARS chars (~$((TOTAL_CHARS/4)) tokens)"
echo "Mode: $MODE"
echo "Strategy: Reading in parallel quantum chunks..."
echo "---"

# Function to read a quantum chunk
read_quantum_chunk() {
    local chunk_id=$1
    local start_line=$2
    local end_line=$3
    local cache_file="$QUANTUM_CACHE/${CACHE_KEY}_chunk_${chunk_id}"

    if [ -f "$cache_file" ] && [ "$cache_file" -nt "$FILE" ]; then
        cat "$cache_file"
        return
    fi

    local content=$(sed -n "${start_line},${end_line}p" "$FILE")
    echo "$content" > "$cache_file"
    echo "$content"
}

# Smart mode: Intelligently select most relevant chunks
smart_read() {
    echo "SMART MODE: Analyzing file structure..."
    local key_sections=$(grep -n "^function\|^class\|^async function\|^export\|=== .* ===" "$FILE" | head -20)
    echo "Key sections found:"
    echo "$key_sections" | head -5
    echo ""
    while IFS=: read -r line_num content; do
        local start=$((line_num - 50))
        local end=$((line_num + 200))
        [ $start -lt 1 ] && start=1
        [ $end -gt $TOTAL_LINES ] && end=$TOTAL_LINES
        echo "### Section at line $line_num: ${content:0:60}..."
        sed -n "${start},${end}p" "$FILE"
        echo ""
    done <<< "$key_sections"
}

# Search mode: Find and read around matches
search_read() {
    local pattern="$1"
    echo "SEARCH MODE: Finding '$pattern'..."
    local matches=$(grep -n "$pattern" "$FILE")
    local match_count=$(echo "$matches" | wc -l)
    echo "Found $match_count matches"
    echo ""
    while IFS=: read -r line_num content; do
        local start=$((line_num - 20))
        local end=$((line_num + 20))
        [ $start -lt 1 ] && start=1
        [ $end -gt $TOTAL_LINES ] && end=$TOTAL_LINES
        echo "### Match at line $line_num ###"
        sed -n "${start},${end}p" "$FILE" | grep -C 20 --color=always "$pattern"
        echo ""
    done <<< "$matches"
}

# Full parallel read mode
parallel_full_read() {
    local num_chunks=$(( (TOTAL_LINES + MAX_LINES_PER_CHUNK - 1) / MAX_LINES_PER_CHUNK ))
    echo "Splitting into $num_chunks quantum chunks..."
    echo "Reading all chunks in parallel..."
    echo ""
    for i in $(seq 1 $num_chunks); do
        local start=$(( (i-1) * MAX_LINES_PER_CHUNK + 1 ))
        local end=$(( i * MAX_LINES_PER_CHUNK ))
        [ $end -gt $TOTAL_LINES ] && end=$TOTAL_LINES
        export -f read_quantum_chunk
        export QUANTUM_CACHE CACHE_KEY FILE
        {
            echo "--- CHUNK $i/$num_chunks (lines $start-$end) ---"
            read_quantum_chunk "$i" "$start" "$end"
            echo ""
        } &
        if [ $((i % 4)) -eq 0 ]; then
            wait
        fi
    done
    wait
    echo "---"
    echo "QUANTUM READ COMPLETE"
    echo "Read $TOTAL_LINES lines in $num_chunks parallel chunks"
}

case "$MODE" in
    smart) smart_read ;;
    search)
        if [ -z "$SEARCH_TERM" ]; then echo "Error: Search mode requires a search term"; exit 1; fi
        search_read "$SEARCH_TERM" ;;
    full) parallel_full_read ;;
    *) echo "Error: Unknown mode: $MODE"; echo "Usage: $0 <file> [full|smart|search] [search_term]"; exit 1 ;;
esac

echo ""
echo "Cache stats:"
ls -lh "$QUANTUM_CACHE/${CACHE_KEY}_chunk_"* 2>/dev/null | wc -l | xargs echo "  Cached chunks:"
du -sh "$QUANTUM_CACHE" 2>/dev/null | xargs echo "  Cache size:"
