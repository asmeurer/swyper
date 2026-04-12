# Changelog

All notable changes to Swyper will be documented in this file.

## [0.4.1] - 2026-04-11

- Restore stable self-signed release signing in GitHub Actions using `RCODESIGN_CERT_PEM` and `RCODESIGN_KEY_PEM`
- Fix ad-hoc bundle signing for local non-release builds
- Remove unsupported release signing fallbacks so published updates always keep a stable code identity
- Document the release secret requirements for self-signed and Apple-signed builds

## [0.4.0] - 2026-04-10

- Add configurable swipe sensitivity with a numeric threshold control
- Add a swipe indicator, show feedback for swipes without shortcuts, and improve indicator contrast
- Fix simulated shortcuts triggering the system beep
- Make the Settings window reliably open and come to the front
- Preserve compatibility when loading existing configs and restore tracked app version fallback
- Add a comprehensive automated test suite and run it in CI on pushes and pull requests
- Improve bundle and release builds by generating the app icon automatically and installing required icon tooling in CI

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
