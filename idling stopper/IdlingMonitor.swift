import AppKit
import CoreGraphics
import Foundation
import Observation

@Observable
final class IdlingMonitor {

    private(set) var isRunning: Bool = false
    private(set) var lastMoveAt: Date?
    private(set) var lastFailureAt: Date?
    private(set) var consecutiveFailureCount: Int = 0
    private(set) var isSystemAsleep: Bool = false
    private(set) var lastReadingAt: Date?

    var debugMode: Bool = false {
        didSet {
            guard debugMode != oldValue, isRunning else { return }
            // Restart the loop so the new (shorter/longer) poll interval
            // takes effect immediately instead of after the current sleep.
            loopTask?.cancel()
            loopTask = Task { [weak self] in
                await self?.runLoop()
            }
        }
    }

    var jiggleDistance: CGFloat = 10

    private let normalIdleThreshold: TimeInterval = 60
    private let normalPollInterval: TimeInterval = 10
    private let debugIdleThreshold: TimeInterval = 5
    private let debugPollInterval: TimeInterval = 1

    var idleThresholdSeconds: TimeInterval {
        debugMode ? debugIdleThreshold : normalIdleThreshold
    }
    var pollIntervalSeconds: TimeInterval {
        debugMode ? debugPollInterval : normalPollInterval
    }

    private let failureAlertThreshold: Int = 10
    private let alertCooldownSeconds: TimeInterval = 24 * 3600
    private let alertCooldownKey: String = "lastAccessibilityAlertAt"

    // 0xFFFFFFFF is the documented wildcard for `secondsSinceLastEventType`,
    // meaning "any input event." It happens to coincide with the Swift
    // enum case `.tapDisabledByUserInput`, but the underlying C API treats
    // the raw value, not the case name.
    private let anyInputEventType = CGEventType(rawValue: ~0)!

    private var loopTask: Task<Void, Never>?
    private var sleepObserver: (any NSObjectProtocol)?
    private var wakeObserver: (any NSObjectProtocol)?
    private var directionSign: CGFloat = 1

    init() {
        attachSleepWakeObservers()
    }

    func start() {
        guard !isRunning else { return }
        isRunning = true
        consecutiveFailureCount = 0
        loopTask = Task { [weak self] in
            await self?.runLoop()
        }
    }

    func stop() {
        loopTask?.cancel()
        loopTask = nil
        isRunning = false
    }

    func toggle() {
        if isRunning {
            stop()
        } else {
            start()
        }
    }

    private func runLoop() async {
        while !Task.isCancelled {
            do {
                try await Task.sleep(for: .seconds(pollIntervalSeconds))
            } catch {
                return
            }
            guard isRunning, !isSystemAsleep else { continue }

            let idleSeconds = CGEventSource.secondsSinceLastEventType(
                .combinedSessionState,
                eventType: anyInputEventType
            )
            lastReadingAt = Date()
            if idleSeconds >= idleThresholdSeconds {
                performJiggle()
            }
        }
    }

    private func performJiggle() {
        guard let origin = currentMouseLocation() else {
            recordFailure()
            return
        }

        let delta = jiggleDistance * directionSign
        let target = CGPoint(x: origin.x + delta, y: origin.y)
        directionSign *= -1

        let source = CGEventSource(stateID: .hidSystemState)
        guard let event = CGEvent(
            mouseEventSource: source,
            mouseType: .mouseMoved,
            mouseCursorPosition: target,
            mouseButton: .left
        ) else {
            recordFailure()
            return
        }
        event.post(tap: .cghidEventTap)

        guard let landed = currentMouseLocation() else {
            recordFailure()
            return
        }
        let moved = abs(landed.x - origin.x) >= 0.5 || abs(landed.y - origin.y) >= 0.5
        if moved {
            consecutiveFailureCount = 0
            lastMoveAt = Date()
        } else {
            recordFailure()
        }
    }

    private func currentMouseLocation() -> CGPoint? {
        CGEvent(source: nil)?.location
    }

    private func recordFailure() {
        consecutiveFailureCount += 1
        lastFailureAt = Date()
        guard consecutiveFailureCount >= failureAlertThreshold else { return }
        maybeShowAccessibilityAlert()
    }

    private func maybeShowAccessibilityAlert() {
        let defaults = UserDefaults.standard
        let now = Date()
        if let last = defaults.object(forKey: alertCooldownKey) as? Date,
           now.timeIntervalSince(last) < alertCooldownSeconds {
            return
        }
        defaults.set(now, forKey: alertCooldownKey)
        PermissionsManager.presentAccessibilityAlert()
    }

    private func attachSleepWakeObservers() {
        let center = NSWorkspace.shared.notificationCenter
        sleepObserver = center.addObserver(
            forName: NSWorkspace.willSleepNotification,
            object: nil,
            queue: .main
        ) { [weak self] _ in
            MainActor.assumeIsolated { self?.isSystemAsleep = true }
        }
        wakeObserver = center.addObserver(
            forName: NSWorkspace.didWakeNotification,
            object: nil,
            queue: .main
        ) { [weak self] _ in
            MainActor.assumeIsolated { self?.isSystemAsleep = false }
        }
    }

}
