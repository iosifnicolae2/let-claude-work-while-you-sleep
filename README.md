# 🌙 Let Claude Work While You Sleep

Your screens go dark. Your Mac pretends to sleep. Claude does not.

A tiny menu bar app for when an AI agent (or a build, or a 40 GB download) needs your Mac all night, but you'd rather not light up the bedroom like an airport runway.

Hit **Start** (or **⌃⌥⌘L** from anywhere) and:

- 🖥️ **screens turn off**, instantly. No waiting for the timer.
- ⚡ **Mac stays awake**. It's not sleeping. It's *resting its eyes*.
- 🖱️ **wiggle the mouse or tap a key**: screens come back, normal sleep rules return, and you get to find out what Claude did.

No Dock icon. No window. No settings. No subscription. Just a moon quietly judging you from the menu bar.

<img src="screenshot.png" alt="The moon menu: Start, Start at Login, Quit" width="360">

## Install

```sh
brew install --cask iosifnicolae2/tap/let-claude-work && open -a LetClaudeWork
```

146 KB. Apple Silicon and Intel. No Xcode needed. Bye with `brew uninstall --cask let-claude-work`.

## Use

Click the 🌙:

| Menu item | What it does |
|---|---|
| **Start** `⌃⌥⌘L` | Lights out, engine on. The shortcut works from any app |
| **Start at Login** | So you never forget to not sleep your Mac |
| **Change Shortcut…** | Press any combo with ⌘, ⌥ or ⌃. ⌃⌥⌘L is taken? Pick your own |
| **Quit** | Your Mac is free to nap again |

## Fine print

- **Lock screen**: if your Mac wants a password after the display sleeps, it'll ask when you come back. Security > convenience.
- **MacBook lid**: closing it still puts the Mac to sleep (unless it's on power with an external display). Physics wins.
- **Needs** macOS 13+.

## How it works

~200 lines of Swift in [`main.swift`](main.swift) and [`Shortcut.swift`](Shortcut.swift). No magic, just five macOS APIs:

- **stay awake**: an `IOPMAssertion` (a "please don't idle-sleep" note the app holds)
- **screens off**: `pmset displaysleepnow`
- **you're back**: `screensDidWakeNotification`, then the note is torn up
- **start at login**: `SMAppService.mainApp`
- **shortcut**: Carbon `RegisterEventHotKey` (old, but needs no Accessibility permission)

Hacking on it: `./build.sh` builds `build/LetClaudeWork.app`, `./release.sh 1.2.3` ships a release that brew picks up.
