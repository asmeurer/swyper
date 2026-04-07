# Swyper

macOS menu bar app that maps three-finger trackpad swipe gestures to per-app keyboard shortcuts.

## Build

```
make bundle    # Build and create build/Swyper.app
make run       # Build and launch
make install   # Copy to /Applications
make clean     # Clean build artifacts
make lint      # Run SwiftLint
```

## Architecture

- **Swift Package Manager** project (Package.swift), macOS 14+, Swift 6 strict concurrency
- **MultitouchSupport.framework** loaded via `dlopen` for raw multitouch gesture detection
- **CGEvent** API for keyboard shortcut simulation
- **SwiftUI** GUI with `MenuBarExtra` and `Settings` scene
- Config stored as JSON in `~/Library/Application Support/Swyper/config.json`
- No sandbox (required for private framework + CGEvent access)

## Key files

- `Sources/MultitouchManager.swift` - Core gesture detection with C callback interop
- `Sources/Models.swift` - Data types shared across the app
- `Sources/AppDelegate.swift` - Wires gesture detection to key simulation
- `Sources/Views/ShortcutRecorderView.swift` - NSViewRepresentable keyboard shortcut capture

## Conventions

- Always commit changes as soon as they are made. Do not batch up multiple unrelated changes.
- Pre-commit hooks run SwiftLint and `swift build` to catch issues before committing.
- Swift 6 strict concurrency: use `@unchecked Sendable` + `OSAllocatedUnfairLock` for thread-safe C interop, `@MainActor` for UI/state classes.
- Avoid silencing exceptions — prefer full tracebacks on errors.
