# Swyper

macOS menu bar app that maps three-finger trackpad swipe gestures to per-app keyboard shortcuts.

## Build

```
make bundle    # Build and create build/Swyper.app
make run       # Build and launch
make install   # Copy to /Applications
make clean     # Clean build artifacts
make lint      # Run SwiftLint
swift test     # Run the test suite
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

## Development

- Tests are in the `Tests/` directory. Run `swift test` to execute the test suite. CI runs tests on pushes and PRs to `main` via `.github/workflows/ci.yml`.
- The release version of Swyper is installed at `/Applications/Swyper.app`. Before running the dev build with `make run`, close the release version first (click the menu bar icon → Quit Swyper) to avoid conflicts.
- Auto-updates use Sparkle. The EdDSA private key is stored as the `SPARKLE_PRIVATE_KEY` GitHub secret. Release builds must use stable signing via either the Apple signing secrets (`APPLE_CODESIGN_*`) or the self-signed `rcodesign` PEM secrets (`RCODESIGN_CERT_PEM` and `RCODESIGN_KEY_PEM`); the release workflow updates `appcast.xml` on each tagged release.

## Releasing

When significant changes have been made (new features, important bug fixes, UI changes), create a release:

1. Update `CHANGELOG.md` with the new version's changes under a `## [x.y.z] - YYYY-MM-DD` heading
2. Bump the version in `VERSION` (semver: major.minor.patch)
3. Commit the changelog and version bump
4. Tag with `git tag v<version>` and push the tag with `git push origin v<version>`
5. The GitHub Actions release workflow (`.github/workflows/release.yml`) handles building, signing, creating the GitHub Release, and updating `appcast.xml` (which includes the changelog so Sparkle shows it in the update dialog)

## Conventions

- Always commit changes as soon as they are made. Do not batch up multiple unrelated changes. Do not ask before committing.
- Pre-commit hooks run SwiftLint and `swift build` to catch issues before committing.
- Swift 6 strict concurrency: use `@unchecked Sendable` + `OSAllocatedUnfairLock` for thread-safe C interop, `@MainActor` for UI/state classes.
- Avoid silencing exceptions — prefer full tracebacks on errors.
- When working in a git worktree, always merge the worktree branch into `main` and push once the work is complete. Use `git checkout main && git merge <worktree-branch> && git push origin main`.
- Always use `git merge`, never `git rebase`. When pulling remote changes, use `git pull` (not `git pull --rebase`).
