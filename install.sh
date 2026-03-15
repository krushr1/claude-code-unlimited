#!/bin/bash

# Claude Code Unlimited Installer v2
# 1M context: ingest everything, edit from line numbers, never re-read

echo "====================================="
echo " Claude Code Unlimited v2 Installer"
echo "====================================="
echo ""
echo "This will install:"
echo "  * Full project ingestion (ccu-ingest.sh)"
echo "  * Smart file reading (no token limits)"
echo "  * Parallel chunk processing"
echo "  * RAM disk caching"
echo "  * Read tool interceptor (disabled by default for 1M context)"
echo ""
echo "Installation directory: ~/.claude/cache"
echo ""

command -v jq >/dev/null 2>&1 || { echo "[!] jq is required but not installed. Install it first."; exit 1; }

REPO_BASE="https://raw.githubusercontent.com/krushr1/claude-code-unlimited/main"

echo "[*] Creating directories..."
mkdir -p ~/.claude/cache
mkdir -p ~/.claude/hooks

for script in ccu-ingest.sh smart-read.sh quantum-read.sh cache-startup.sh cache-live.sh; do
    echo "[*] Downloading $script..."
    command -v curl >/dev/null 2>&1 && curl -sL "$REPO_BASE/$script" -o ~/.claude/cache/$script
    chmod +x ~/.claude/cache/$script
done

echo "[*] Downloading Read tool interceptor..."
command -v curl >/dev/null 2>&1 && curl -sL "$REPO_BASE/hooks/smart-read-interceptor.sh" -o ~/.claude/hooks/smart-read-interceptor.sh
chmod +x ~/.claude/hooks/smart-read-interceptor.sh

if [ -f ~/.claude/settings.json ]; then
    echo "[*] Backing up existing settings.json..."
    cp ~/.claude/settings.json ~/.claude/settings.json.backup.20260315-135724

    if grep -q "SessionStart\|PreToolUse" ~/.claude/settings.json; then
        echo "[!] Hooks already configured in settings.json"
        echo "[!] Add these hooks manually if not present:"
        echo ""
        echo "  SessionStart hook (auto-ingest):"
        echo '    { "type": "command", "command": "~/.claude/cache/ccu-ingest.sh" }'
        echo ""
        echo "  PreToolUse Read hook (interceptor, disabled by default):"
        echo '    { "matcher": "Read", "hooks": [{ "type": "command", "command": "~/.claude/hooks/smart-read-interceptor.sh" }] }'
    else
        echo "[!] Please manually add hooks to settings.json — see CLAUDE.md for the JSON snippet"
    fi
else
    echo "[*] Creating new settings.json with hook configuration..."
    python3 -c "
import json, pathlib
cfg = {
    \"hooks\": {
        \"SessionStart\": [{\"type\": \"command\", \"command\": \"~/.claude/cache/ccu-ingest.sh\"}],
        \"PreToolUse\": [{\"matcher\": \"Read\", \"hooks\": [{\"type\": \"command\", \"command\": \"~/.claude/hooks/smart-read-interceptor.sh\"}]}]
    }
}
pathlib.Path.home().joinpath('.claude', 'settings.json').write_text(json.dumps(cfg, indent=2))
"
fi

echo ""
echo "[*] Verifying installation..."
ok=true
for f in ~/.claude/cache/ccu-ingest.sh ~/.claude/cache/smart-read.sh ~/.claude/cache/quantum-read.sh ~/.claude/cache/cache-startup.sh ~/.claude/cache/cache-live.sh ~/.claude/hooks/smart-read-interceptor.sh; do
    [ ! -f "$f" ] && { echo "[!] Missing: $f"; ok=false; }
done
$ok && echo "[OK] All files installed successfully!" || { echo "[!] Some files missing"; exit 1; }

echo ""
echo "====================================="
echo " Installation Complete!"
echo "====================================="
echo ""
echo "v2 workflow (1M context):"
echo "  1. Start a new Claude Code session"
echo "  2. CCU auto-ingests your project with line numbers"
echo "  3. Edit directly from context — no re-reads needed"
echo ""
echo "Manual ingest:  ~/.claude/cache/ccu-ingest.sh"
echo "RAM disk cache: ~/.claude/cache/cache-startup.sh start"
echo "Live cache:     ~/.claude/cache/cache-live.sh start"
echo ""
echo "Add the CLAUDE.md snippet to your project for best results."
echo "See: CLAUDE.md in the repo for the full snippet."
