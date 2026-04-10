# Claude Code Tab Notifications

See at a glance which Claude Code terminal needs your attention.

When you're running multiple Claude Code sessions in VS Code or Cursor, the terminal tab sidebar shows generic "bash" for every tab. This makes it impossible to tell sessions apart, see which sessions are waiting for input and which are still working.

This project uses Claude Code [hooks](https://docs.anthropic.com/en/docs/claude-code/hooks) and the standard OSC 0 terminal escape sequence to rename tabs based on session status:

| State | Tab title |
|-------|-----------|
| Working | `Fix auth middleware` |
| Waiting for input | `🔔 WAITING — Fix auth middleware` |
| Task complete | `✅ DONE — Fix auth middleware` |

The topic is pulled from Claude Code's session metadata — it's the auto-generated conversation summary.

## How it works

```
Claude Code fires Notification hook
  → sleep 1 (wait for Claude's own title to settle)
  → claude-tab-title reads session_id from hook stdin
  → looks up conversation topic in ~/.claude/projects/*/sessions-index.json
  → sets terminal title via OSC 0 escape (printf '\033]0;TITLE\007')
  → VS Code/Cursor picks it up via ${sequence} tab title variable
```

## Requirements

- **Claude Code** (CLI, v2.1+)
- **VS Code** or **Cursor**
- **jq** (`brew install jq` / `apt install jq`)
- **macOS** or **Linux**

## Install

### Automatic

```bash
git clone https://github.com/faroceann/claude-code-tab-notifications.git
cd claude-code-tab-notifications
./install.sh
```

The install script:
1. Copies `claude-tab-title` to `~/.local/bin/`
2. Adds `Notification` and `Stop` hooks to `~/.claude/settings.json`
3. Sets `terminal.integrated.tabs.title` to `${sequence}` in your VS Code/Cursor user settings

### Manual

**1. Install the script**

```bash
cp claude-tab-title ~/.local/bin/
chmod +x ~/.local/bin/claude-tab-title
```

Make sure `~/.local/bin` is on your `PATH`:
```bash
export PATH="$HOME/.local/bin:$PATH"  # add to ~/.zshrc or ~/.bashrc
```

**2. Add Claude Code hooks**

Add to `~/.claude/settings.json`:

```json
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
```

The `async: true` and `sleep 1` are important — Claude Code manages its own terminal title, and the delay ensures our title is set *after* Claude's internal title update.

**3. Configure VS Code / Cursor**

Open user settings JSON (`Cmd+Shift+P` → "Preferences: Open User Settings (JSON)") and add:

```json
{
  "terminal.integrated.tabs.title": "${sequence}",
  "terminal.integrated.tabs.description": "${task}${separator}${local}"
}
```

This tells the editor to use the OSC 0 escape sequence as the tab title instead of the default process name.

**4. Restart Claude Code**

Hooks are snapshotted at session startup. Restart any running sessions to pick up the new hooks.

## Combining with other notification hooks

The tab rename works well alongside other notification methods. For example, you can add macOS native notifications in the same hook:

```json
{
  "hooks": {
    "Notification": [
      {
        "matcher": "",
        "hooks": [
          {
            "type": "command",
            "command": "terminal-notifier -title '🔔 Claude Code' -message 'Claude needs your input'"
          },
          {
            "type": "command",
            "command": "sleep 1 && claude-tab-title waiting",
            "async": true
          }
        ]
      }
    ]
  }
}
```

## Troubleshooting

**Tab doesn't change at all**
- Verify `terminal.integrated.tabs.title` is set to `"${sequence}"` in your user settings
- Check that `claude-tab-title` is on your PATH: `which claude-tab-title`
- Check that `jq` is installed: `which jq`

**Tab changes briefly then reverts to "Claude Code"**
- Make sure the hook has `"async": true` — without it the hook blocks and Claude Code overwrites the title
- Try increasing the sleep: `"sleep 2 && claude-tab-title waiting"`

**Topic shows directory name instead of conversation summary**
- New sessions won't have a summary until after the first exchange
- The session must exist in `~/.claude/projects/*/sessions-index.json`

**Hooks not firing**
- Hooks are loaded at session start — restart Claude Code after editing settings
- Verify your settings JSON is valid: `jq . ~/.claude/settings.json`

## Why not use the terminal bell?

VS Code's bell decoration (`terminal.integrated.enableVisualBell`) is purely time-based — it fades after `bellDuration` and there's no setting to make it persist until acknowledged. There's an [open feature request](https://github.com/microsoft/vscode/issues/119778) for this that's been sitting for years.

The OSC 0 approach sets the title persistently — it stays until something explicitly overwrites it.

## Why the `sleep 1`?

Claude Code has its own internal terminal title management. When it finishes processing or enters an idle state, it sets the terminal title to "Claude Code" (or the conversation topic via `/rename`). Without the delay, our hook fires first but Claude Code immediately overwrites it. The 1-second async delay ensures our title is set *after* Claude's internal update.

## License

MIT
