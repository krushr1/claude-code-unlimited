#!/bin/bash

# Claude Code Unlimited Installer
# Break free from the 25,000 token limit

echo "===================================="
echo " Claude Code Unlimited Installer"
echo "===================================="
echo ""
echo "This will install:"
echo "  * Smart file reading (no token limits)"
echo "  * Parallel chunk processing" 
echo "  * RAM disk caching"
echo "  * Automatic Read tool interception"
echo ""
echo "Installation directory: ~/.claude/cache"
echo ""

# Check for required commands
command -v jq >/dev/null 2>&1 || { echo "[!] jq is required but not installed. Install it first."; exit 1; }

# Create directories
echo "[*] Creating directories..."
mkdir -p ~/.claude/cache
mkdir -p ~/.claude/hooks

# Install smart-read.sh
echo "[*] Installing smart-read.sh..."
cp smart-read.sh ~/.claude/cache/
chmod +x ~/.claude/cache/smart-read.sh

# Install quantum-read.sh
echo "[*] Installing quantum-read.sh..."
cp quantum-read.sh ~/.claude/cache/
chmod +x ~/.claude/cache/quantum-read.sh

# Install cache-startup.sh
echo "[*] Installing cache-startup.sh..."
cp cache-startup.sh ~/.claude/cache/
chmod +x ~/.claude/cache/cache-startup.sh

# Install Read tool interceptor hook
echo "[*] Installing Read tool interceptor..."
cp hooks/smart-read-interceptor.sh ~/.claude/hooks/
chmod +x ~/.claude/hooks/smart-read-interceptor.sh

# Update settings.json if it exists
if [ -f ~/.claude/settings.json ]; then
    echo "[*] Backing up existing settings.json..."
    cp ~/.claude/settings.json ~/.claude/settings.json.backup.$(date +%Y%m%d)
    
    echo "[*] Updating settings.json with hook configuration..."
    # This would need proper JSON manipulation
    echo "[!] Please manually add the hook configuration to ~/.claude/settings.json"
    echo "    See README.md for details"
else
    echo "[*] Creating new settings.json with hook configuration..."
    cat > ~/.claude/settings.json << 'EOF'
{
  "hooks": {
    "PreToolUse": [
      {
        "matcher": "Read",
        "hooks": [
          {
            "type": "command",
            "command": "~/.claude/hooks/smart-read-interceptor.sh"
          }
        ]
      }
    ]
  }
}
EOF
fi

echo ""
echo "===================================="
echo " Installation Complete!"
echo "===================================="
echo ""
echo "Quick test:"
echo "  $ ~/.claude/cache/smart-read.sh /path/to/large/file.js"
echo ""
echo "The Read tool will now automatically handle large files!"
echo ""
echo "For more information, see README.md"