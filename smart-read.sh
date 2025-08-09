#!/bin/bash

# Claude Code Unlimited - Smart Read v2.0
# Intelligently chooses read method based on file size
# Bypasses Claude Code's 25k token limit with quantum processing

FILE="$1"
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

if [ ! -f "$FILE" ]; then
    echo "❌ Error: File not found: $FILE"
    exit 1
fi

# Get file stats
FILE_SIZE=$(stat -f%z "$FILE" 2>/dev/null || stat -c%s "$FILE" 2>/dev/null)
FILE_LINES=$(wc -l < "$FILE")

# Estimate tokens (approximate: 1 token ≈ 4 chars)
ESTIMATED_TOKENS=$((FILE_SIZE / 4))

echo "📊 File Analysis:"
echo "   Path: $FILE"
echo "   Size: $(numfmt --to=iec-i --suffix=B $FILE_SIZE 2>/dev/null || echo "$FILE_SIZE bytes")"
echo "   Lines: $FILE_LINES"
echo "   Est. Tokens: ~$ESTIMATED_TOKENS"
echo "   Method: Smart routing enabled"
echo ""

# Smart routing based on file size
if [ $ESTIMATED_TOKENS -lt 20000 ]; then
    echo "✅ Small file - Direct read"
    echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
    cat "$FILE"
elif [ $ESTIMATED_TOKENS -lt 100000 ]; then
    echo "⚡ Medium file - Smart quantum read"
    echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
    if [ -f "$SCRIPT_DIR/quantum-read.sh" ]; then
        bash "$SCRIPT_DIR/quantum-read.sh" "$FILE" "smart"
    else
        echo "⚠️ Quantum reader not found, showing first 500 lines"
        head -500 "$FILE"
    fi
else
    echo "🚀 Large file - Full parallel quantum read"
    echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
    if [ -f "$SCRIPT_DIR/quantum-read.sh" ]; then
        bash "$SCRIPT_DIR/quantum-read.sh" "$FILE" "full"
    else
        echo "⚠️ Quantum reader not found, showing first 1000 lines"
        head -1000 "$FILE"
    fi
fi