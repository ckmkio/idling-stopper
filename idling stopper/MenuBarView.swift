import SwiftUI

struct MenuBarView: View {

    @Bindable var monitor: IdlingMonitor
    @AppStorage("selectedIcon") private var rawIcon: String = IconOption.default.rawValue

    private static let lastMoveFormatter: DateFormatter = {
        let formatter = DateFormatter()
        formatter.timeStyle = .medium
        formatter.dateStyle = .none
        return formatter
    }()

    var body: some View {
        Group {
            statusSection
            Divider()
            controlSection
            Divider()
            iconPicker
            Divider()
            debugSection
            Divider()
            footerSection
        }
    }

    @ViewBuilder
    private var statusSection: some View {
        Text(statusText)
        Text("Last move: \(lastMoveText)")
        if monitor.consecutiveFailureCount > 0 {
            Text("Recent failures: \(monitor.consecutiveFailureCount)")
        }
    }

    private var statusText: String {
        if monitor.isRunning {
            monitor.isSystemAsleep ? "Paused (system asleep)" : "Active"
        } else {
            "Inactive"
        }
    }

    private var lastMoveText: String {
        monitor.lastMoveAt.map(Self.lastMoveFormatter.string(from:)) ?? "Never"
    }

    private var controlSection: some View {
        Group {
            if monitor.isRunning {
                Button("Stop") { monitor.stop() }
            } else {
                Button("Start") { monitor.start() }
            }
        }
    }

    private var iconPicker: some View {
        Menu("Icon") {
            ForEach(IconOption.allCases) { option in
                Button {
                    rawIcon = option.rawValue
                } label: {
                    if option.rawValue == rawIcon {
                        Label(option.label, systemImage: "checkmark")
                    } else {
                        Text(option.label)
                    }
                }
            }
        }
    }

    @ViewBuilder
    private var debugSection: some View {
        Toggle("Debug mode (faster polling)", isOn: $monitor.debugMode)
        if monitor.debugMode {
            Text(String(
                format: "Threshold: %.0fs  ·  Poll: %.0fs",
                monitor.idleThresholdSeconds,
                monitor.pollIntervalSeconds
            ))
            if let readingAt = monitor.lastReadingAt {
                Text("Last check: \(Self.lastMoveFormatter.string(from: readingAt))")
            }
        }
    }

    private var footerSection: some View {
        Group {
            Button("Open Accessibility Settings…") {
                PermissionsManager.openAccessibilitySettings()
            }
            Button("Quit") {
                NSApplication.shared.terminate(nil)
            }
            .keyboardShortcut("q")
        }
    }
}
