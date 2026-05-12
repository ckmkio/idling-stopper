# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

## Project

A macOS menu-bar app that prevents the system from registering as idle by jiggling the mouse pointer when no input has been seen for a threshold. SwiftUI + `MenuBarExtra`. Bundle id `io.ckmk.idling-stopper`. Deployment target macOS 26.3, Swift 5.

The project name contains a space (`idling stopper`), so all `xcodebuild` invocations must quote it.

## Common commands

Build (Debug):
```
xcodebuild -project "idling stopper.xcodeproj" -scheme "idling stopper" -configuration Debug build
```

Run the unit-test bundle:
```
xcodebuild test -project "idling stopper.xcodeproj" -scheme "idling stopper" -destination 'platform=macOS'
```

Run a single test (Swift Testing):
```
xcodebuild test -project "idling stopper.xcodeproj" -scheme "idling stopper" -destination 'platform=macOS' \
  -only-testing:idling_stopperTests/idling_stopperTests/example
```

Open in Xcode:
```
open "idling stopper.xcodeproj"
```

There is no separate lint step; rely on the Swift compiler under strict concurrency.

## Architecture

Four source files form a small star around a single long-lived monitor object.

- `idling_stopperApp.swift` — `@main`. Constructs **one** `IdlingMonitor` and passes it to `MenuBarView`. Two `@AppStorage` keys drive UX: `selectedIcon` (menu-bar SF Symbol) and `autoStartOnLaunch` (whether `monitor.start()` runs in `init`). The scene is a `MenuBarExtra` with `.menu` style — there is no main window.

- `IdlingMonitor.swift` — `@Observable` class that owns the polling loop and all runtime state.
  - Idle detection uses `CGEventSource.secondsSinceLastEventType(.combinedSessionState, eventType: anyInputEventType)` where `anyInputEventType` is `CGEventType(rawValue: ~0)!` (the documented `0xFFFFFFFF` wildcard). Do not replace this with a named `CGEventType` case — the comment in the file explains why the raw value matters.
  - Jiggling is done by reading the cursor location, posting a synthesized `mouseMoved` `CGEvent` 10pt to the side (alternating direction via `directionSign`), then re-reading the cursor to verify it actually moved. A non-move increments `consecutiveFailureCount` and, after 10 failures, triggers `PermissionsManager.presentAccessibilityAlert()` with a 24h `UserDefaults` cooldown (`lastAccessibilityAlertAt`).
  - Two timing profiles: normal (60s idle threshold / 10s poll) and `debugMode` (5s / 1s). Toggling `debugMode` while running cancels and restarts `loopTask` so the new interval takes effect immediately instead of after the current `Task.sleep` completes.
  - Sleep/wake handling: observes `NSWorkspace.willSleepNotification` / `didWakeNotification` and skips the jiggle while `isSystemAsleep`. The observer callbacks use `MainActor.assumeIsolated` because the workspace center delivers on the main queue.

- `PermissionsManager.swift` — Static helpers for Accessibility (AX) trust. `isAccessibilityTrusted` passes `"AXTrustedCheckOptionPrompt"` as a string key (instead of the `kAXTrustedCheckOptionPrompt` global) to sidestep Swift 6 strict-concurrency complaints about the non-`Sendable` CF constant. `openAccessibilitySettings` uses the `x-apple.systempreferences:` URL scheme.

- `MenuBarView.swift` — SwiftUI content for the menu. Reads state directly off the `@Bindable` monitor (status, last-move time, failure count, debug toggle). `IconOption.swift` is a closed enum of SF Symbol choices for the menu-bar glyph.

## Things to know before editing

- **Accessibility permission is mandatory.** Without it, `CGEvent.post` silently fails — the cursor doesn't move, `consecutiveFailureCount` climbs, and the alert flow fires. When testing changes to the jiggle path on a fresh build, expect to re-grant Accessibility to the new binary in System Settings.
- **The monitor must be a single instance** owned by `IdlingStopperApp`. The sleep/wake observers and the polling task are tied to its lifetime; creating a second one (e.g. in a preview or test) will double-post events.
- `MenuBarExtra` with `.menu` style means SwiftUI rebuilds the view tree each time the menu opens; keep `MenuBarView` cheap and avoid stashing state there — put it on `IdlingMonitor`.
- Swift concurrency is strict in this target. New async paths should use `Task` cancellation (see `runLoop`'s `try await Task.sleep` + `Task.isCancelled` pattern) rather than timers.
