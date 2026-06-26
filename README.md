# Clipr

A local-first, visual clipboard history manager for macOS — lives in your menu bar.

![macOS](https://img.shields.io/badge/macOS-13%2B-black) ![Swift](https://img.shields.io/badge/Swift-5.9-orange) ![License](https://img.shields.io/badge/license-MIT-blue)

## Features

- **Visual grid** — every clip shown as a card: screenshots, colors, code, URLs, files, text
- **Instant search** — full-text across content, OCR text, and URL titles
- **Type filters** — filter by Text, Image, URL, Color, Code, File
- **Pin clips** — keep important clips at the top
- **Incognito mode** — pause capture with one click
- **On-device OCR** — Apple Vision extracts text from screenshots automatically
- **Quick Paste** — global `Ctrl+Cmd+V` overlay to paste without leaving your keyboard
- **Sensitive data filtering** — skips password managers, credit cards, API keys automatically

## Privacy

- No cloud sync, no analytics, no telemetry
- All data stored locally in `~/Library/Application Support/Clipr/`
- OCR runs entirely on-device via Apple Vision

## Tech

- Swift + SwiftUI (macOS 13+)
- [GRDB](https://github.com/groue/GRDB.swift) for local SQLite storage
- `MenuBarExtra` popover UI
- `CGEventTap` for global hotkey (requires Accessibility permission)

## Building

1. Open `Clipr.xcodeproj` in Xcode 15+
2. Set your development team in project settings
3. Build & run (`Cmd+R`)

> Distributed as a DMG — not available on the Mac App Store (CGEventTap requires full Accessibility access).

## License

MIT
