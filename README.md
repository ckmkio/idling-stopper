# Idling Stopper

A tiny macOS menu-bar app that keeps your Mac (and any presence-aware apps watching it) from being marked **idle** by nudging the mouse pointer a few pixels whenever no input has been seen for a while.

No window, no dock icon — just a single SF Symbol in the menu bar.

## Features

- Lives entirely in the menu bar via `MenuBarExtra`.
- Detects idle time with the system input clock (`CGEventSource.secondsSinceLastEventType`) — no polling of mouse position, no heuristics.
- Jiggles the cursor 10pt horizontally (alternating direction) when idle exceeds the threshold, then verifies the cursor actually moved.
- Auto-pauses while the system is asleep (`NSWorkspace.willSleepNotification` / `didWakeNotification`).
- Auto-starts on launch by default (toggleable via `autoStartOnLaunch` in `UserDefaults`).
- Choose between four menu-bar icons (Cursor, Cloud, Person, Hexagon).
- Debug mode shortens the idle threshold to 5s and the poll interval to 1s for quick verification.
- If the cursor fails to move 10 times in a row (typically because Accessibility access is missing), shows an alert with a 24-hour cooldown and a one-click shortcut to the right pane of System Settings.

## Default timing

| Mode   | Idle threshold | Poll interval |
| ------ | -------------- | ------------- |
| Normal | 60s            | 10s           |
| Debug  | 5s             | 1s            |

Switching debug mode while the monitor is running restarts the loop so the new interval takes effect immediately.

## Requirements

- macOS 26.3 or later
- Xcode with Swift 5 toolchain (project uses Swift Testing for unit tests)
- **Accessibility permission** for the app — without it, synthesized mouse events are silently dropped by the system.

## Granting Accessibility access

1. Build and launch the app once.
2. Open **System Settings → Privacy & Security → Accessibility**.
3. Enable **idling stopper** in the list.
4. Quit and reopen the app.

The menu also has an **Open Accessibility Settings…** shortcut that jumps directly to the correct pane.

## Build & run

Open in Xcode:

```sh
open "idling stopper.xcodeproj"
```

Or from the command line:

```sh
xcodebuild -project "idling stopper.xcodeproj" \
           -scheme "idling stopper" \
           -configuration Debug build
```

Run tests:

```sh
xcodebuild test -project "idling stopper.xcodeproj" \
                -scheme "idling stopper" \
                -destination 'platform=macOS'
```

The project name contains a space, so the quotes are required.

## Project layout

```
idling stopper/
├── idling_stopperApp.swift   # @main, MenuBarExtra scene, owns the IdlingMonitor
├── IdlingMonitor.swift       # @Observable polling loop, jiggle + sleep/wake handling
├── MenuBarView.swift         # SwiftUI menu content
├── PermissionsManager.swift  # Accessibility trust check, alert, settings shortcut
├── IconOption.swift          # Menu-bar icon choices
└── Assets.xcassets
```

See `CLAUDE.md` for an architectural overview aimed at code-editing agents.

## How it works

Every poll tick the monitor asks the window server how long it has been since *any* input event:

```swift
CGEventSource.secondsSinceLastEventType(
    .combinedSessionState,
    eventType: CGEventType(rawValue: ~0)!  // 0xFFFFFFFF == "any event"
)
```

If that exceeds the threshold, the monitor:

1. Reads the current cursor location.
2. Posts a synthesized `mouseMoved` `CGEvent` 10pt to the side.
3. Reads the cursor again and confirms it moved by at least 0.5pt.

Step 3 is the failure signal: if the cursor *doesn't* move, that almost always means Accessibility access is missing, and the failure counter advances toward the alert.

## License

Personal project — no license declared.
