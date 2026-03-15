#!/bin/bash
# Smart Read Interceptor — DISABLED (1M context, no file size limits needed)
exit 0
# Intercepts Read tool calls for large files and redirects to smart-read

# Read input from stdin
INPUT=$(cat)
TOOL_NAME=$(echo "$INPUT" | jq -r '.toolName // empty')
FILE_PATH=$(echo "$INPUT" | jq -r '.toolInput.file_path // empty')

if [ "$TOOL_NAME" != "Read" ]; then exit 0; fi

if [ -f "$FILE_PATH" ]; then
    FILE_SIZE=$(stat -f%z "$FILE_PATH" 2>/dev/null || stat -c%s "$FILE_PATH" 2>/dev/null)
    ESTIMATED_TOKENS=$((FILE_SIZE / 4))
    if [ $ESTIMATED_TOKENS -gt 20000 ]; then
        echo "[Claude Code Unlimited] Large file detected (~$ESTIMATED_TOKENS tokens)" >&2
        echo "[Claude Code Unlimited] Redirecting to smart-read..." >&2
        bash ~/.claude/cache/smart-read.sh "$FILE_PATH"
        echo '{"permissionDecision": "deny", "message": "File handled by Claude Code Unlimited"}'
        exit 2
    fi
fi
exit 0
