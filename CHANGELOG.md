# Changelog

All notable changes to Swyper will be documented in this file.

## [0.3.0] - 2026-04-09

- Replace intrusive accessibility permission dialog with a non-blocking menu bar prompt
- Redesign app icon with SVG source
- Add dev version suffix to distinguish development builds from release builds
- Switch to rcodesign for stable code signing that preserves Accessibility permissions across rebuilds
- Add App Management permission instructions for auto-updates

## [0.2.0] - 2026-04-07

- Add app icon with three-finger swipe gesture design
- Add GitHub Pages website for the project
- Fix Sparkle appcast signing for auto-updates

## [0.1.0] - 2026-04-07

Initial release.

- Three-finger trackpad swipe gesture detection (left/right/up/down) via MultitouchSupport framework
- Per-application keyboard shortcut mapping
- macOS menu bar app with SwiftUI settings interface
- Keyboard shortcut recorder for capturing custom shortcuts
- Configuration stored as JSON in `~/Library/Application Support/Swyper/config.json`
- App icon with three-finger swipe gesture design
- Sparkle-based automatic updates
- GitHub Actions release workflow
