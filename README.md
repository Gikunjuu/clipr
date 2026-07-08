# Clipr

A local-first, visual clipboard history manager for macOS — lives in your menu bar and stays out of the way.

[![Download](https://img.shields.io/badge/Download-v1.0-blue)](https://github.com/Gikunjuu/clipr/releases/download/v1.0/Clipr-v1.0.dmg)

![Clipr demo](clipr-demo.gif)

## Features

- Captures text, images, links, code, colors, and file paths automatically
- Visual card grid with content previews
- Duplicate detection — promotes existing cards instead of creating duplicates
- Copy count badge on frequently copied items
- OCR on images so you can search text inside screenshots
- Incognito mode — pause capture for passwords and sensitive data
- Pin clips to keep them at the top
- Multi-select clips and paste them all at once
- Single-click any card to instantly paste into your previous app
- Double-click a text card to edit it before pasting
- Filter by content type or source app
- Search across all clips including OCR text
- Hotkey customization — set your own shortcut to open Quick Paste
- Auto-expire — automatically delete clips older than 1, 7, 14, 30, or 90 days
- Launch at Login support
- No cloud sync, no analytics, all data stays on your Mac

## Download

Grab the latest DMG from [Releases](https://github.com/Gikunjuu/clipr/releases).

### First Launch (Gatekeeper)

Because Clipr is not notarized, macOS will block it the first time. To clear this:

```bash
xattr -cr /Applications/Clipr.app
```

Then open it normally from Spotlight or `/Applications`.

## How it works

Clipr watches the system clipboard using `NSPasteboard` change-count polling and stores everything locally in SQLite (via GRDB) and a flat file store in `~/Library/Application Support/Clipr/`.

The notch panel is a borderless `NSWindow` that sits at the top center of your screen. Clicking your menu bar icon or pressing the global hotkey (default `⇧ ⌘ V`) expands it. Clicking a card writes it back to the pasteboard and sends a synthetic `Cmd+V` to your previous app via `CGEventTap` (requires Accessibility permission).

## Settings

Click the gear icon in the panel header to open Settings:

- **Quick Paste Hotkey** — click the shortcut field and press your desired key combo
- **Auto-expire Clips** — choose how long to keep clips before they are automatically deleted (pinned clips are never deleted)

## Requirements

- macOS 13 Ventura or later
- Accessibility permission (required for paste simulation and the global hotkey)

## Building from source

```bash
git clone https://github.com/Gikunjuu/clipr.git
cd clipr/Clipr
open Clipr.xcodeproj
```

Build and run in Xcode. The app requires no external build tools — GRDB is embedded directly.
