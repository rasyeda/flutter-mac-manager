# FlutterMacManager

A lightweight, native macOS menu bar app (`SwiftUI` + `MenuBarExtra`) for discovering, inspecting, resetting data for, and cleaning installed Flutter desktop **Debug** and **Profile** `.app` builds.

## Features

- **Menu Bar Native (`LSUIElement`)**: Lives quietly in your macOS menu bar with no Dock icon.
- **Automatic Discovery**: Scans configured project directories (`**/build/macos/Build/Products/{Debug,Profile}/*.app`), Xcode `DerivedData`, and optionally `/Applications`. Excludes Release builds and non-Flutter apps.
- **Disk Footprint & Inspector**:
  - Summary bar showing total builds (`Debug`/`Profile`), running instances, and combined disk footprint.
  - Expandable per-app inspector with a proportional storage breakdown bar (App Bundle vs. Library Data vs. DerivedData), one-click path copy, and **Reveal in Finder**.
  - Highlights shared containers when Debug and Profile builds share the same `CFBundleIdentifier`.
- **Reset App Data**: Clears `~/Library/Containers`, `Application Support`, `Preferences` (including `cfprefsd` cache flush via `defaults delete`), `Caches`, `Saved Application State`, and `HTTPStorages`, with an option to preserve Preferences.
- **Clean Builds & Stale Artifacts**: Removes `.app` binaries and matching `DerivedData`, or bulk-cleans builds older than 7, 14, or 30 days.
- **Safety Guardrails**:
  - Moves items to macOS Trash by default (`FileManager.trashItem`) so deletions are recoverable.
  - Strict path allowlist validator prevents touching system paths or Release builds.
  - Detects running instances via `NSWorkspace` and offers to quit them before cleanup.
  - Preview confirmation screen listing every path and byte count before execution.

## Requirements

- macOS 13.0 (Ventura) or later
- Swift 5.9+ (Xcode Command Line Tools)

## Build & Run

```bash
# Run unit tests
swift test

# Build release binary and package FlutterMacManager.app
./scripts/bundle_app.sh

# Launch in the menu bar
open dist/FlutterMacManager.app
```

To install permanently, copy `dist/FlutterMacManager.app` to `/Applications/`.

## Architecture

- `Sources/FlutterMacManagerCore/` — Reusable core library (`AppScanner`, `DataFootprintService`, `CleanupService`, models, settings).
- `Sources/FlutterMacManager/` — SwiftUI `MenuBarExtra` application and views.
- `Tests/FlutterMacManagerTests/` — Unit tests for Flutter Debug/Profile detection and path safety guardrails.
- `scripts/bundle_app.sh` — Packages the compiled release binary into a standalone `.app` bundle with `LSUIElement = true`.

## License

MIT
