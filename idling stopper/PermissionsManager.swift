import AppKit
import ApplicationServices

enum PermissionsManager {

    static func isAccessibilityTrusted(prompt: Bool = false) -> Bool {
        // `kAXTrustedCheckOptionPrompt` is a non-Sendable global in
        // ApplicationServices that trips strict concurrency. The CF
        // constant's value has been stable since 10.9.
        let options: NSDictionary = ["AXTrustedCheckOptionPrompt": prompt]
        return AXIsProcessTrustedWithOptions(options as CFDictionary)
    }

    static func openAccessibilitySettings() {
        let url = URL(string: "x-apple.systempreferences:com.apple.preference.security?Privacy_Accessibility")!
        NSWorkspace.shared.open(url)
    }

    static func presentAccessibilityAlert() {
        let alert = NSAlert()
        alert.alertStyle = .warning
        alert.messageText = "Idling Stopper needs Accessibility access"
        alert.informativeText = """
            To move the mouse pointer on your behalf, Idling Stopper needs to be \
            granted Accessibility access.

            Open System Settings → Privacy & Security → Accessibility, enable \
            “idling stopper”, then quit and reopen the app.
            """
        alert.addButton(withTitle: "Open Settings")
        alert.addButton(withTitle: "Later")

        NSApp.activate(ignoringOtherApps: true)
        if alert.runModal() == .alertFirstButtonReturn {
            openAccessibilitySettings()
        }
    }
}
