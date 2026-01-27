import AppKit

@MainActor
final class HoverTracker {
    var zone: () -> CGRect? = { nil }
    var onChange: (Bool) -> Void = { _ in }
    var holdOpen: () -> Bool = { false }

    private let openDelay: Duration
    private let closeDelay: Duration
    private var monitors: [Any] = []
    private var pollTimer: Timer?
    private var pending: Task<Void, Never>?
    private var isInside = false

    init(openDelay: Duration = .milliseconds(150), closeDelay: Duration = .milliseconds(350)) {
        self.openDelay = openDelay
        self.closeDelay = closeDelay
    }

    func start() {
        let events: NSEvent.EventTypeMask = [.mouseMoved, .leftMouseDragged]
        if let monitor = NSEvent.addGlobalMonitorForEvents(matching: events, handler: { [weak self] _ in
            MainActor.assumeIsolated { self?.update() }
        }) {
            monitors.append(monitor)
        }
        if let monitor = NSEvent.addLocalMonitorForEvents(matching: events, handler: { [weak self] event in
            MainActor.assumeIsolated { self?.update() }
            return event
        }) {
            monitors.append(monitor)
        }
    }

    func stop() {
        monitors.forEach(NSEvent.removeMonitor)
        monitors.removeAll()
        setPolling(false)
        pending?.cancel()
    }

    func update(force: Bool = false) {
        let inside = zone()?.contains(NSEvent.mouseLocation) ?? false
        guard force || inside != isInside else { return }
        isInside = inside
        setPolling(inside)
        schedule(inside)
    }

    private func schedule(_ inside: Bool) {
        pending?.cancel()
        let delay = inside ? openDelay : closeDelay
        pending = Task { [weak self] in
            try? await Task.sleep(for: delay)
            guard !Task.isCancelled, let self else { return }
            if !inside, holdOpen() { return }
            onChange(inside)
        }
    }

    private func setPolling(_ enabled: Bool) {
        pollTimer?.invalidate()
        pollTimer = nil
        guard enabled else { return }
        pollTimer = Timer.scheduledTimer(withTimeInterval: 0.1, repeats: true) { [weak self] _ in
            MainActor.assumeIsolated { self?.update() }
        }
    }
}
