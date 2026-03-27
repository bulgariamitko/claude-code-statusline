#!/bin/bash
# Install or update Claude Code Status Line
# Usage: curl -sf https://raw.githubusercontent.com/bulgariamitko/claude-code-statusline/main/install.sh | bash

set -e

REPO_RAW="https://raw.githubusercontent.com/bulgariamitko/claude-code-statusline/main"
DEST="$HOME/.claude/statusline.sh"
SETTINGS="$HOME/.claude/settings.json"

G='\033[0;32m'; Y='\033[1;33m'; C='\033[0;36m'; R='\033[0m'; D='\033[0;90m'

echo -e "${C}Claude Code Status Line Installer${R}"
echo ""

# Check if already installed
if [ -f "$DEST" ]; then
  current=$(grep '^STATUSLINE_VERSION=' "$DEST" 2>/dev/null | sed 's/STATUSLINE_VERSION="\(.*\)"/\1/')
  echo -e "${D}Current version: ${current:-unknown}${R}"
fi

# Download
echo -e "${Y}Downloading latest statusline.sh...${R}"
mkdir -p "$HOME/.claude"
curl -sf "$REPO_RAW/statusline.sh" -o "$DEST.tmp"

new_version=$(grep '^STATUSLINE_VERSION=' "$DEST.tmp" 2>/dev/null | sed 's/STATUSLINE_VERSION="\(.*\)"/\1/')
mv "$DEST.tmp" "$DEST"
chmod +x "$DEST"

echo -e "${G}Installed v${new_version}${R} → ${DEST}"

# Configure settings.json if not already set
if [ -f "$SETTINGS" ]; then
  if grep -q '"statusLine"' "$SETTINGS" 2>/dev/null; then
    echo -e "${D}settings.json already configured${R}"
  else
    echo -e "${Y}Note:${R} Add this to your ${SETTINGS}:"
    echo -e '  "statusLine": { "type": "command", "command": "~/.claude/statusline.sh", "padding": 0 }'
  fi
else
  echo -e "${Y}Creating settings.json...${R}"
  cat > "$SETTINGS" << 'EOF'
{
  "statusLine": {
    "type": "command",
    "command": "~/.claude/statusline.sh",
    "padding": 0
  }
}
EOF
  echo -e "${G}Created${R} ${SETTINGS}"
fi

# Clear update cache
rm -f "$HOME/.claude/.statusline_cache/update_available" 2>/dev/null
rm -f "$HOME/.claude/.statusline_cache/update_check" 2>/dev/null

echo ""
echo -e "${G}Done!${R} Restart Claude Code to see the status line."
