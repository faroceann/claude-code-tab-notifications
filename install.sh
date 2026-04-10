#!/bin/bash
# Installs claude-tab-title and configures Claude Code hooks + VS Code/Cursor settings.
# Run: curl -sSL <raw-url>/install.sh | bash
# Or:  git clone <repo> && cd claude-code-tab-notifications && ./install.sh

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

echo "==> Installing claude-tab-title"

# 1. Install the script
INSTALL_DIR="${HOME}/.local/bin"
mkdir -p "$INSTALL_DIR"
cp "$SCRIPT_DIR/claude-tab-title" "$INSTALL_DIR/claude-tab-title"
chmod +x "$INSTALL_DIR/claude-tab-title"

# Verify it's on PATH
if ! command -v claude-tab-title &>/dev/null; then
  echo ""
  echo "    WARNING: $INSTALL_DIR is not on your PATH."
  echo "    Add this to your shell profile (~/.zshrc or ~/.bashrc):"
  echo ""
  echo "        export PATH=\"\$HOME/.local/bin:\$PATH\""
  echo ""
fi

# 2. Check for jq dependency
if ! command -v jq &>/dev/null; then
  echo ""
  echo "    WARNING: jq is required but not installed."
  echo "    Install it: brew install jq (macOS) or apt install jq (Linux)"
  echo ""
fi

# 3. Configure Claude Code hooks
CLAUDE_SETTINGS="${HOME}/.claude/settings.json"

if [ -f "$CLAUDE_SETTINGS" ]; then
  # Check if tab-title hooks already exist
  if jq -e '.hooks.Notification[0].hooks[] | select(.command | test("claude-tab-title"))' "$CLAUDE_SETTINGS" &>/dev/null; then
    echo "    claude-tab-title hooks already configured — skipping."
    echo "    To update manually, see README.md for the hooks JSON."
  else
    # Merge hooks into existing settings
    jq '.hooks = (.hooks // {}) * {
      "SessionStart": [{
        "matcher": "",
        "hooks": [{
          "type": "command",
          "command": "sleep 1 && claude-tab-title active",
          "async": true
        }]
      }],
      "UserPromptSubmit": [{
        "matcher": "",
        "hooks": [{
          "type": "command",
          "command": "sleep 1 && claude-tab-title active",
          "async": true
        }]
      }],
      "Notification": [{
        "matcher": "",
        "hooks": [{
          "type": "command",
          "command": "sleep 1 && claude-tab-title waiting",
          "async": true
        }]
      }],
      "Stop": [{
        "matcher": "",
        "hooks": [{
          "type": "command",
          "command": "sleep 1 && claude-tab-title done",
          "async": true
        }]
      }]
    }' "$CLAUDE_SETTINGS" > "${CLAUDE_SETTINGS}.tmp" && mv "${CLAUDE_SETTINGS}.tmp" "$CLAUDE_SETTINGS"
    echo "    Added hooks to $CLAUDE_SETTINGS"
  fi
else
  # Create settings file with just hooks
  mkdir -p "$(dirname "$CLAUDE_SETTINGS")"
  cat > "$CLAUDE_SETTINGS" <<'SETTINGS'
{
  "hooks": {
    "SessionStart": [
      {
        "matcher": "",
        "hooks": [
          {
            "type": "command",
            "command": "sleep 1 && claude-tab-title active",
            "async": true
          }
        ]
      }
    ],
    "UserPromptSubmit": [
      {
        "matcher": "",
        "hooks": [
          {
            "type": "command",
            "command": "sleep 1 && claude-tab-title active",
            "async": true
          }
        ]
      }
    ],
    "Notification": [
      {
        "matcher": "",
        "hooks": [
          {
            "type": "command",
            "command": "sleep 1 && claude-tab-title waiting",
            "async": true
          }
        ]
      }
    ],
    "Stop": [
      {
        "matcher": "",
        "hooks": [
          {
            "type": "command",
            "command": "sleep 1 && claude-tab-title done",
            "async": true
          }
        ]
      }
    ]
  }
}
SETTINGS
  echo "    Created $CLAUDE_SETTINGS with hooks"
fi

# 4. Configure VS Code / Cursor terminal tab settings
configure_editor() {
  local name="$1"
  local settings_path="$2"

  if [ ! -f "$settings_path" ]; then
    return
  fi

  if jq -e '."terminal.integrated.tabs.title"' "$settings_path" &>/dev/null; then
    echo "    $name terminal.integrated.tabs.title already set — skipping."
  else
    jq '. + {
      "terminal.integrated.tabs.title": "${sequence}",
      "terminal.integrated.tabs.description": "${task}${separator}${local}"
    }' "$settings_path" > "${settings_path}.tmp" && mv "${settings_path}.tmp" "$settings_path"
    echo "    Added terminal tab settings to $name"
  fi
}

# macOS paths
VSCODE_SETTINGS="${HOME}/Library/Application Support/Code/User/settings.json"
CURSOR_SETTINGS="${HOME}/Library/Application Support/Cursor/User/settings.json"

# Linux paths
if [ "$(uname)" = "Linux" ]; then
  VSCODE_SETTINGS="${HOME}/.config/Code/User/settings.json"
  CURSOR_SETTINGS="${HOME}/.config/Cursor/User/settings.json"
fi

configure_editor "VS Code" "$VSCODE_SETTINGS"
configure_editor "Cursor" "$CURSOR_SETTINGS"

echo ""
echo "==> Done! Restart any running Claude Code sessions to activate."
echo "    Tab titles will show:"
echo "      🔔 WAITING — <topic>   when Claude needs your input"
echo "      ✅ DONE — <topic>      when Claude finishes a task"
echo ""
