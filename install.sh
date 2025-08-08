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
command -v curl >/dev/null 2>&1 || { echo "[!] curl is required but not installed."; exit 1; }

# GitHub repo base URL
REPO_URL="https://raw.githubusercontent.com/krushr1/claude-code-unlimited/main"

# Create directories
echo "[*] Creating directories..."
mkdir -p ~/.claude/cache
mkdir -p ~/.claude/hooks

# Download and install smart-read.sh
echo "[*] Downloading smart-read.sh..."
curl -sL "$REPO_URL/smart-read.sh" -o ~/.claude/cache/smart-read.sh
chmod +x ~/.claude/cache/smart-read.sh

# Download and install quantum-read.sh
echo "[*] Downloading quantum-read.sh..."
curl -sL "$REPO_URL/quantum-read.sh" -o ~/.claude/cache/quantum-read.sh
chmod +x ~/.claude/cache/quantum-read.sh

# Download and install cache-startup.sh
echo "[*] Downloading cache-startup.sh..."
curl -sL "$REPO_URL/cache-startup.sh" -o ~/.claude/cache/cache-startup.sh
chmod +x ~/.claude/cache/cache-startup.sh

# Download and install Read tool interceptor hook
echo "[*] Downloading Read tool interceptor..."
curl -sL "$REPO_URL/hooks/smart-read-interceptor.sh" -o ~/.claude/hooks/smart-read-interceptor.sh
chmod +x ~/.claude/hooks/smart-read-interceptor.sh

# Update settings.json if it exists
if [ -f ~/.claude/settings.json ]; then
    echo "[*] Backing up existing settings.json..."
    cp ~/.claude/settings.json ~/.claude/settings.json.backup.$(date +%Y%m%d-%H%M%S)
    
    # Check if PreToolUse hook already exists
    if grep -q "PreToolUse" ~/.claude/settings.json; then
        echo "[!] PreToolUse hooks already configured in settings.json"
        echo "[!] Please manually add the Read tool interceptor to your hooks"
        echo ""
        echo "Add this to your PreToolUse hooks array:"
        echo '  {'
        echo '    "matcher": "Read",'
        echo '    "hooks": ['
        echo '      {'
        echo '        "type": "command",'
        echo '        "command": "~/.claude/hooks/smart-read-interceptor.sh"'
        echo '      }'
        echo '    ]'
        echo '  }'
    else
        echo "[*] Adding hook configuration to settings.json..."
        # This is complex JSON manipulation - for safety, just inform user
        echo "[!] Please manually add the hook configuration to ~/.claude/settings.json"
        echo ""
        echo "Add this to your settings.json:"
        echo '"hooks": {'
        echo '  "PreToolUse": ['
        echo '    {'
        echo '      "matcher": "Read",'
        echo '      "hooks": ['
        echo '        {'
        echo '          "type": "command",'
        echo '          "command": "~/.claude/hooks/smart-read-interceptor.sh"'
        echo '        }'
        echo '      ]'
        echo '    }'
        echo '  ]'
        echo '}'
    fi
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

# Verify installation
echo ""
echo "[*] Verifying installation..."
if [ -f ~/.claude/cache/smart-read.sh ] && [ -f ~/.claude/cache/quantum-read.sh ] && [ -f ~/.claude/cache/cache-startup.sh ]; then
    echo "[✓] All files installed successfully!"
else
    echo "[!] Some files may not have installed correctly"
    exit 1
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
echo "For more information: https://github.com/krushr1/claude-code-unlimited"