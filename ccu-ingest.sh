#!/bin/bash
# CCU Ingest v3 — Full project ingestion for 1M context models
# Reads every eligible file with line numbers into a single context file.
# After ingestion, Claude never needs to re-read those files for the rest of the session.
#
# How it works:
#   1. Collects all git-tracked files, filtering binary/vendor/build artifacts
#   2. Extracts a symbol index (functions, classes, exports) with file:line refs
#   3. Scores files by git hotness (recent commits = higher priority)
#   4. Outputs every file as path:linenum: content (grep-compatible format)
#   5. Stops when the token budget is hit, lists remaining files for manual Read
#
# Output: ~/.claude/cache/ccu-context.txt (read this once at session start)
#
# Environment variables:
#   CCU_MAX_TOKENS       — total token budget (default: 800000)
#   CCU_MAX_FILE_TOKENS  — per-file token limit (default: 800000)

MAX_TOKENS="${CCU_MAX_TOKENS:-800000}"
MAX_FILE_TOKENS="${CCU_MAX_FILE_TOKENS:-800000}"
EXCLUDE_DIRS="node_modules|dist|build|\.git|vendor|__pycache__|\.next|\.nuxt|\.svelte-kit|\.cache|\.turbo|coverage|\.tox|\.mypy_cache|\.pytest_cache|target/debug|target/release|\.venv|venv|\.eggs"
EXCLUDE_EXTS="png|jpg|jpeg|gif|webp|svg|ico|woff|woff2|ttf|eot|otf|mp3|mp4|wav|avi|mov|mkv|flac|ogg|zip|tar|gz|bz2|7z|rar|xz|pdf|doc|docx|xls|xlsx|ppt|pptx|exe|dll|so|dylib|o|a|pyc|pyo|class|wasm|min\.js|min\.css|lock|sum|map|db|sqlite|sqlite3"
MANIFEST="$HOME/.claude/cache/ccu-ingested.txt"
ROOT_FILE="$HOME/.claude/cache/ccu-project-root.txt"

# Detect project root
PROJECT_ROOT=$(git rev-parse --show-toplevel 2>/dev/null)
if [ -z "$PROJECT_ROOT" ]; then
    echo "[CCU] No git repo detected. Ingest skipped." >&2
    exit 0
fi

# Skip home dir and .claude internals
if [ "$PROJECT_ROOT" = "$HOME" ] || [[ "$PROJECT_ROOT" == "$HOME/.claude"* ]]; then
    exit 0
fi
PROJECT_NAME=$(basename "$PROJECT_ROOT")

# Collect eligible files from git index
collect_files() {
    git -C "$PROJECT_ROOT" ls-files -z 2>/dev/null | while IFS= read -r -d '' f; do
        local full="$PROJECT_ROOT/$f"
        [ ! -f "$full" ] && continue
        echo "$f" | grep -qE "($EXCLUDE_DIRS)" && continue
        local ext="${f##*.}"
        echo "$ext" | grep -qiE "^($EXCLUDE_EXTS)$" && continue
        echo "$full"
    done
}

# Extract symbols (functions, classes, exports) with file:line references
extract_symbols() {
    local file="$1"
    local rel="${file#$PROJECT_ROOT/}"
    local ext="${file##*.}"
    case "$ext" in
        js|jsx|ts|tsx|mjs|mts)
            grep -nE '^export (default )?(function|class|const|let|var|type|interface|enum) +[A-Za-z_]' "$file" 2>/dev/null
            grep -nE '^(function|class) +[A-Za-z_]' "$file" 2>/dev/null
            ;;
        py)
            grep -nE '^(def|class) +[A-Za-z_]' "$file" 2>/dev/null
            ;;
        go)
            grep -nE '^(func|type) +[A-Za-z_]' "$file" 2>/dev/null
            ;;
        rs)
            grep -nE '^(pub )?(fn|struct|enum|trait|impl|mod) +[A-Za-z_]' "$file" 2>/dev/null
            ;;
        rb)
            grep -nE '^[ ]*(def|class|module) +[A-Za-z_]' "$file" 2>/dev/null
            ;;
        sh|bash|zsh)
            grep -nE '^[a-zA-Z_][a-zA-Z_0-9]*\(\)' "$file" 2>/dev/null
            ;;
    esac | while IFS=: read -r ln content; do
        local name=$(echo "$content" | grep -oE '(function|class|const|let|var|type|interface|enum|def|func|fn|struct|trait|impl|mod|module) +[A-Za-z_][A-Za-z_0-9]*' | tail -1 | awk '{print $NF}')
        [ -z "$name" ] && name=$(echo "$content" | grep -oE '^[A-Za-z_][A-Za-z_0-9]*')
        [ -n "$name" ] && printf "%-30s -> %s:%s\n" "$name" "$rel" "$ln"
    done
}

# Recent git changes (last 7 days)
recent_changes() {
    git -C "$PROJECT_ROOT" log --since="7 days ago" --pretty=format:'' --name-only --diff-filter=M 2>/dev/null |
        sort -u | head -20 | while read -r f; do
            [ -z "$f" ] && continue
            local stats=$(git -C "$PROJECT_ROOT" log --since="7 days ago" --pretty=format:'' --numstat -- "$f" 2>/dev/null | awk '{a+=$1;d+=$2}END{if(a+d>0)printf "+%d/-%d",a,d}')
            local msg=$(git -C "$PROJECT_ROOT" log --since="7 days ago" -1 --pretty=format:'%s' -- "$f" 2>/dev/null)
            [ -n "$stats" ] && echo "$f: $stats — ${msg:0:60}"
        done
}

# Score files by git activity (recent = hot = loaded first)
compute_file_hotness() {
    local file_list="$1"
    local scores_file="$2"
    local score_map=$(mktemp)
    git -C "$PROJECT_ROOT" log --format='%at' --name-only 2>/dev/null | awk -v now="$(date +%s)" '
    /^[0-9]+$/ { ts=$0; next }
    NF > 0 {
        age = (now - ts) / 86400
        if (age < 7) w = 10
        else if (age < 30) w = 5
        else if (age < 90) w = 2
        else w = 1
        score[$0] += w
    }
    END { for (f in score) print score[f] "\t" f }
    ' > "$score_map"
    while IFS= read -r f; do
        local rel="${f#$PROJECT_ROOT/}"
        local score=$(awk -F'\t' -v r="$rel" '$2 == r {print $1; exit}' "$score_map")
        [ -z "$score" ] && score=0
        # Boost entry-point files
        case "$rel" in
            *main.*|*router.*|*handler.*|*server.*|*app.*|*index.*|cmd/*|CLAUDE.md)
                score=$((score + 50)) ;;
        esac
        printf "%s\t%s\n" "$score" "$f"
    done < "$file_list" > "$scores_file"
    rm -f "$score_map"
}

# Main
main() {
    local start_time=$(date +%s)
    mkdir -p "$(dirname "$MANIFEST")"
    : > "$MANIFEST"
    echo "$PROJECT_ROOT" > "$ROOT_FILE"

    local file_list=$(mktemp)
    collect_files > "$file_list"
    local file_count=$(wc -l < "$file_list" | tr -d ' ')

    if [ "$file_count" -eq 0 ]; then
        echo "[CCU] No eligible files found in $PROJECT_NAME. Ingest skipped." >&2
        rm -f "$file_list"
        exit 0
    fi

    # Launch concurrent extraction tasks
    local scores_file=$(mktemp)
    compute_file_hotness "$file_list" "$scores_file" &
    local hotness_pid=$!

    local sym_output=$(mktemp)
    (
        while IFS= read -r f; do
            local syms=$(extract_symbols "$f")
            [ -n "$syms" ] && echo "$syms"
        done < "$file_list"
    ) > "$sym_output" &
    local sym_pid=$!

    local changes_output=$(mktemp)
    recent_changes > "$changes_output" &
    local changes_pid=$!

    local sizes_file=$(mktemp)
    (
        while IFS= read -r f; do
            printf "%d\t%s\n" "$(wc -c < "$f" 2>/dev/null || echo 0)" "$f"
        done < "$file_list"
    ) > "$sizes_file" &
    local sizes_pid=$!

    wait "$sizes_pid"
    wait "$hotness_pid"

    local total_bytes=$(awk -F'\t' '{s+=$1}END{print s+0}' "$sizes_file")
    local est_tokens=$((total_bytes / 4))

    local sorted_list=$(mktemp)
    sort -t$'\t' -rn "$scores_file" | cut -f2 > "$sorted_list"

    local context_file="$HOME/.claude/cache/ccu-context.txt"

    {
        echo "CCU v3: PROJECT INGEST"
        echo "Project: $PROJECT_NAME | Files: $file_count | Est. tokens: ~$est_tokens"
        echo "Budget: $MAX_TOKENS tokens | $(date -u +%Y-%m-%dT%H:%M:%SZ)"
        echo ""

        wait "$sym_pid"
        echo "## SYMBOL INDEX"
        local sym_content=$(cat "$sym_output")
        [ -n "$sym_content" ] && echo "$sym_content" || echo "(no symbols extracted)"
        echo ""

        wait "$changes_pid"
        echo "## RECENT CHANGES (7d)"
        local changes=$(cat "$changes_output")
        [ -n "$changes" ] && echo "$changes" || echo "(no recent changes)"
        echo ""

        echo "## FILES"
        echo ""

        local loaded_tokens=0
        local loaded_files=0
        local skipped_budget=0
        local skipped_size=0

        while IFS= read -r f; do
            local sz=$(grep -F "$f" "$sizes_file" 2>/dev/null | head -1 | cut -f1)
            [ -z "$sz" ] && sz=$(wc -c < "$f" 2>/dev/null || echo 0)
            local ftokens=$((sz / 4))
            local rel="${f#$PROJECT_ROOT/}"
            local lines=$(wc -l < "$f" 2>/dev/null || echo 0)

            if [ "$ftokens" -gt "$MAX_FILE_TOKENS" ]; then
                echo "--- $rel (SKIPPED: ~${ftokens} tokens > ${MAX_FILE_TOKENS} limit, use Read tool) ---"
                ((skipped_size++))
                continue
            fi

            if [ $((loaded_tokens + ftokens)) -gt "$MAX_TOKENS" ]; then
                echo "--- BUDGET REACHED ($loaded_tokens/$MAX_TOKENS tokens) ---"
                echo "Remaining files (use Read tool):"
                while IFS= read -r rem; do
                    echo "  - ${rem#$PROJECT_ROOT/}"
                done
                skipped_budget=$((file_count - loaded_files - skipped_size))
                break
            fi

            # KEY: every line gets path:linenum: prefix for direct editing
            echo "--- $rel ($lines lines, ~${ftokens} tok) ---"
            awk -v p="$rel" '{printf "%s:%d: %s\n", p, NR, $0}' "$f"
            echo ""

            echo "$f" >> "$MANIFEST"
            loaded_tokens=$((loaded_tokens + ftokens))
            ((loaded_files++))
        done < "$sorted_list"

        local end_time=$(date +%s)
        local elapsed=$((end_time - start_time))

        echo ""
        echo "INGEST COMPLETE"
        echo "Loaded: $loaded_files files | ~$loaded_tokens tokens | ${elapsed}s"
        [ "$skipped_size" -gt 0 ] && echo "Skipped (too large): $skipped_size"
        [ "$skipped_budget" -gt 0 ] && echo "Skipped (budget): $skipped_budget"
        echo ""
        echo "## SESSION RULES"
        echo "- EDIT DIRECTLY: use old_lines with the line numbers shown above"
        echo "- DO NOT re-read ingested files — they are already in your context"
        echo "- DO NOT grep the project — search your context window instead"
        echo "- Files outside this project or skipped files: use Read/Grep normally"
    } > "$context_file"

    echo "[CCU] $PROJECT_NAME | $loaded_files files | ~${loaded_tokens} tokens | ${elapsed}s" >&2
    echo "[CCU] Context written to: $context_file" >&2

    rm -f "$file_list" "$scores_file" "$sorted_list" "$sym_output" "$changes_output" "$sizes_file"
}

main "$@"
