import SwiftUI

@main
struct IdlingStopperApp: App {

    private let monitor = IdlingMonitor()

    @AppStorage("selectedIcon") private var rawIcon: String = IconOption.default.rawValue
    @AppStorage("autoStartOnLaunch") private var autoStartOnLaunch: Bool = true

    init() {
        if autoStartOnLaunch {
            monitor.start()
        }
    }

    var body: some Scene {
        MenuBarExtra {
            MenuBarView(monitor: monitor)
        } label: {
            Image(systemName: currentIcon.symbolName)
                .accessibilityLabel("Idling Stopper")
        }
        .menuBarExtraStyle(.menu)
    }

    private var currentIcon: IconOption {
        IconOption(rawValue: rawIcon) ?? .default
    }
}
