# 🌙 Let Claude Work While You Sleep

Your screens go dark. Your Mac pretends to sleep. Claude does not.

A tiny menu bar app for when an AI agent (or a build, or a 40 GB download) needs your Mac all night, but you'd rather not light up the bedroom like an airport runway.

Hit **Start** and:

- 🖥️ **screens turn off**, instantly. No waiting for the timer.
- ⚡ **Mac stays awake**. It's not sleeping. It's *resting its eyes*.
- 🖱️ **wiggle the mouse or tap a key**: screens come back, normal sleep rules return, and you get to find out what Claude did.

No Dock icon. No window. No settings. No subscription. Just a moon quietly judging you from the menu bar.

## Install

```sh
git clone https://github.com/iosifnicolae2/let-claude-work-while-you-sleep && cd let-claude-work-while-you-sleep && ./install.sh
```

Compiles from source, drops the app in `/Applications`, starts it. Needs Xcode Command Line Tools (`xcode-select --install`) if you don't have them already.

## Use

Click the 🌙:

| Menu item | What it does |
|---|---|
| **Start** | Lights out, engine on |
| **Start at Login** | So you never forget to not sleep your Mac |
| **Quit** | Your Mac is free to nap again |

## Fine print

- **Lock screen**: if your Mac wants a password after the display sleeps, it'll ask when you come back. Security > convenience.
- **MacBook lid**: closing it still puts the Mac to sleep (unless it's on power with an external display). Physics wins.
- **Needs** macOS 13+.

## How it works

~90 lines of Swift in [`main.swift`](main.swift). No magic, just four macOS APIs:

- **stay awake**: an `IOPMAssertion` (a "please don't idle-sleep" note the app holds)
- **screens off**: `pmset displaysleepnow`
- **you're back**: `screensDidWakeNotification`, then the note is torn up
- **start at login**: `SMAppService.mainApp`
