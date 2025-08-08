#!/bin/bash

# Smart Read Interceptor Hook
# Intercepts Read tool calls for large files and redirects to smart-read

# Read input from stdin
INPUT=$(cat)

# Extract tool name and file path from input
TOOL_NAME=$(echo "$INPUT" | jq -r '.toolName // empty')
FILE_PATH=$(echo "$INPUT" | jq -r '.toolInput.file_path // empty')

# Only process Read tool calls
if [ "$TOOL_NAME" != "Read" ]; then
    # Not a Read tool, allow it
    exit 0
fi

# Check if file exists and get size
if [ -f "$FILE_PATH" ]; then
    FILE_SIZE=$(stat -f%z "$FILE_PATH" 2>/dev/null || stat -c%s "$FILE_PATH" 2>/dev/null)
    ESTIMATED_TOKENS=$((FILE_SIZE / 4))
    
    # If file is too large for Read tool (>25k tokens)
    if [ $ESTIMATED_TOKENS -gt 20000 ]; then
        echo "[Claude Code Unlimited] Large file detected (~$ESTIMATED_TOKENS tokens)" >&2
        echo "[Claude Code Unlimited] Redirecting to smart-read..." >&2
        
        # Run smart-read and output to stdout
        bash ~/.claude/cache/smart-read.sh "$FILE_PATH"
        
        # Block the original Read tool call
        echo '{"permissionDecision": "deny", "message": "File handled by Claude Code Unlimited"}'
        exit 2
    fi
fi

# Allow normal Read tool for small files
exit 0