# Claude Clipboard Cleaner

macOS MenuBar app that automatically cleans Claude Code terminal output when you copy it.

## What it does

When you copy text from Claude Code's terminal, it comes with trailing space padding and leading 2-space indentation. This app detects that pattern and strips it automatically — so your paste is always clean.

**Two detection paths:**
- **Trailing space padding** — terminal copy pads lines to uniform width with spaces
- **Leading 2-space pattern** — Claude response text consistently uses 2-space indent

## Install

```bash
brew install --cask esc5221/tap/claude-clipboard-cleaner
```

Or download the DMG from [Releases](https://github.com/esc5221/claude-clipboard-cleaner/releases).

## Usage

Launch the app — it sits in your menu bar as **⌘C**. That's it.

- Clipboard is monitored automatically (0.3s polling)
- Icon flashes **✓** when a clean happens
- Click the menu bar icon for Enable/Disable, Launch at Login, and clean count

## Build from source

```bash
git clone https://github.com/esc5221/claude-clipboard-cleaner.git
cd claude-clipboard-cleaner
./build.sh
open "build/Claude Clipboard Cleaner.app"
```

## Test

```bash
./test.sh
```

## Requirements

- macOS 13.0+ (Ventura)
- Apple Silicon (arm64)

## License

MIT
