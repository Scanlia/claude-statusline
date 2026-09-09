#!/usr/bin/env bash
# Install the status line into ~/.claude.
# Usage: bash install.sh   (or run it straight from the repo, see README)
set -euo pipefail

CLAUDE_DIR="${CLAUDE_CONFIG_DIR:-$HOME/.claude}"
SCRIPT_URL="https://raw.githubusercontent.com/Scanlia/claude-statusline/main/statusline-command.sh"
TARGET="$CLAUDE_DIR/statusline-command.sh"
SETTINGS="$CLAUDE_DIR/settings.json"

mkdir -p "$CLAUDE_DIR"

# Prefer the local copy when running inside a clone, otherwise fetch it.
# Both files present means we really are in the repo, not just piped from curl.
SRC_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" 2>/dev/null && pwd || echo)"
if [ -n "$SRC_DIR" ] && [ -f "$SRC_DIR/statusline-command.sh" ] && [ -f "$SRC_DIR/install.sh" ]; then
    cp "$SRC_DIR/statusline-command.sh" "$TARGET"
else
    curl -fsSL "$SCRIPT_URL" -o "$TARGET"
fi
chmod +x "$TARGET"
echo "installed $TARGET"

# Keep the portable $HOME form unless the config dir has been moved elsewhere.
if [ "$CLAUDE_DIR" = "$HOME/.claude" ]; then
    STATUSLINE_CMD='bash "$HOME/.claude/statusline-command.sh"'
else
    STATUSLINE_CMD="bash \"$TARGET\""
fi

# Merge the statusLine block into settings.json, leaving everything else alone.
python3 - "$SETTINGS" "$STATUSLINE_CMD" <<'PY'
import json, os, sys
path = sys.argv[1]
try:
    with open(path) as f:
        settings = json.load(f)
except FileNotFoundError:
    settings = {}
except json.JSONDecodeError:
    sys.exit(f"{path} is not valid JSON, not touching it. Add the statusLine block by hand.")

settings["statusLine"] = {"type": "command", "command": sys.argv[2]}
os.makedirs(os.path.dirname(path), exist_ok=True)
with open(path, "w") as f:
    json.dump(settings, f, indent=2)
    f.write("\n")
print(f"updated {path}")
PY

command -v jq >/dev/null 2>&1 || echo "warning: jq is not installed, the status line needs it"
echo "Done. Restart Claude Code, or it will pick up on the next render."
