# GenMonBar

A macOS menu bar app inspired by the [XFCE Generic Monitor plugin](https://docs.xfce.org/panel-plugins/xfce4-genmon-plugin/start): each widget shows an **emoji** followed by the output of a **shell command** in the status bar, refreshed on an interval.

```
🍺 3          🧠 42%          📦 12
```

<img width="310" height="207" alt="image" src="https://github.com/user-attachments/assets/cf812727-ef04-49d5-8765-141425b1b446" />

## Install

Via [Homebrew](https://brew.sh) (personal tap):

```sh
brew install --cask DennisFaucher/tap/genmonbar
```

> GenMonBar is not Developer ID signed/notarized, so macOS Gatekeeper blocks it on first launch. Right-click `/Applications/GenMonBar.app` and choose **Open**, or run:
>
> ```sh
> xattr -dr com.apple.quarantine "/Applications/GenMonBar.app"
> ```
>
> You can also install without the quarantine attribute: `brew install --cask --no-quarantine DennisFaucher/tap/genmonbar`

Update / uninstall:

```sh
brew upgrade --cask genmonbar
brew uninstall --cask genmonbar        # add --zap to also remove its config
```

Or download the latest `GenMonBar.app.zip` from the [releases page](https://github.com/DennisFaucher/GenMonBar/releases).


## Build & run

```sh
make run          # develop: swift run
make app-bundle   # produces GenMonBar.app (LSUIElement, no Dock icon)
open GenMonBar.app
```

## Usage

- Each widget = emoji + command + refresh interval (seconds). The **first non-empty line** of stdout is shown; empty output shows `—`, errors show `⚠️`.
- **Click a widget** for a menu: Run Now, Copy Output, Edit Widgets…, Quit.
- **Edit Widgets…** opens the settings window: add/remove widgets, edit fields, toggle enabled, and ▶ Test a command before saving.
- Full command output and last-run time are in the **tooltip** (hover).

## Configuration

Stored at `~/Library/Application Support/GenMonBar/config.json`. The file is watched — hand-editing works and applies live:

```json
{
  "widgets": [
    {
      "id": "…",
      "emoji": "🍺",
      "command": "brew outdated --greedy | wc -l | tr -d ' '",
      "interval": 3600,
      "enabled": true
    }
  ]
}
```

## Behavior notes

- Commands run via your login shell (`$SHELL -lc`) with Homebrew paths on `PATH`, so `brew` etc. work from the menu bar app.
- 10-second command timeout; long-running commands are terminated.
- Timers use the user's wall clock — `interval` is in seconds, minimum 1.
