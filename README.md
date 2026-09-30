# 🌙 Let Claude Work

Walk away. Screens go dark. Your Mac keeps working.

A tiny menu bar app for long-running jobs (AI agents, builds, downloads). Hit **Start** and:

- 🖥️ **screens turn off**, right away
- ⚡ **Mac stays awake**, no system sleep
- 🖱️ **move the mouse or press a key**: screens come back, normal sleep rules return

No Dock icon, no window, no settings. Just a moon in the menu bar.

## Install

```sh
git clone https://github.com/<you>/let-claude-work && cd let-claude-work && ./install.sh
```

Compiles from source (needs Xcode Command Line Tools: `xcode-select --install`), copies the app to `/Applications` and starts it.

## Use

Click the 🌙 in the menu bar:

| Menu item | What it does |
|---|---|
| **Start** | Screens off, Mac awake, until you come back |
| **Start at Login** | Launch automatically when you log in |
| **Quit** | Bye |

## Good to know

- **Lock screen**: if your Mac asks for a password after the display sleeps, you'll see it when you return.
- **MacBook lid**: closing it still sleeps the Mac, unless it's on power with an external display.
- **Requires** macOS 13+.

## How it works

~90 lines of Swift in [`main.swift`](main.swift):

- **stay awake**: an `IOPMAssertion` (a "don't idle-sleep" flag held by the app)
- **screens off**: `pmset displaysleepnow`
- **you're back**: listens for `screensDidWakeNotification`, then releases the flag
- **start at login**: `SMAppService.mainApp`
