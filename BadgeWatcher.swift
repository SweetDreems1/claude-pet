// Watches the red badge counters on Dock icons. macOS doesn't let other apps read notifications,
// but a growing badge (Telegram, Mail, …) is a good sign that one just arrived.
import AppKit

final class BadgeWatcher {
    private static let pollInterval: TimeInterval = 3
    private var lastCounts: [pid_t: Int] = [:]
    private var timer: Timer?
    private let onNewBadge: (NSRunningApplication) -> Void

    init(onNewBadge: @escaping (NSRunningApplication) -> Void) {
        self.onNewBadge = onNewBadge
    }

    func start() {
        lastCounts = currentCounts()   // don't announce badges that were already there
        timer = Timer.scheduledTimer(withTimeInterval: Self.pollInterval, repeats: true) { [weak self] _ in
            self?.poll()
        }
    }

    /// Reads badges off the main thread so the pet's animation doesn't stutter.
    private func poll() {
        let previous = lastCounts
        DispatchQueue.global(qos: .utility).async { [weak self] in
            guard let self else { return }
            let counts = currentCounts()
            DispatchQueue.main.async {
                for (pid, count) in counts where count > (previous[pid] ?? 0) {
                    if let app = NSRunningApplication(processIdentifier: pid) { self.onNewBadge(app) }
                }
                self.lastCounts = counts
            }
        }
    }

    private func currentCounts() -> [pid_t: Int] {
        var counts: [pid_t: Int] = [:]
        for app in NSWorkspace.shared.runningApplications where app.activationPolicy == .regular {
            counts[app.processIdentifier] = Self.badgeCount(pid: app.processIdentifier)
        }
        return counts
    }

    /// Badge text from `lsappinfo` ("3", "•", …); a non-number badge counts as 1.
    private static func badgeCount(pid: pid_t) -> Int {
        let process = Process()
        process.executableURL = URL(fileURLWithPath: "/usr/bin/lsappinfo")
        process.arguments = ["info", "-only", "StatusLabel", "\(pid)"]
        let pipe = Pipe()
        process.standardOutput = pipe
        process.standardError = FileHandle.nullDevice
        do { try process.run() } catch { return 0 }
        process.waitUntilExit()
        let output = String(data: pipe.fileHandleForReading.readDataToEndOfFile(), encoding: .utf8) ?? ""
        guard let range = output.range(of: "\"label\"=\""),
              let end = output[range.upperBound...].firstIndex(of: "\"") else { return 0 }
        let label = output[range.upperBound..<end]
        if label.isEmpty { return 0 }
        return Int(label) ?? 1
    }
}

/// Small floating app icon shown next to the pet for a few seconds.
final class IconPopup {
    static let size = NSSize(width: 34, height: 34)
    static let visibleSeconds: TimeInterval = 3
    let window = makeOverlayWindow(size: IconPopup.size)
    private let imageView = NSImageView(frame: NSRect(origin: .zero, size: IconPopup.size))
    private var hideWork: DispatchWorkItem?

    init() {
        window.level = .statusBar
        window.ignoresMouseEvents = true
        imageView.imageScaling = .scaleProportionallyUpOrDown
        window.contentView = imageView
    }

    var isShowing: Bool { window.isVisible }

    func show(_ icon: NSImage?) {
        imageView.image = icon
        window.alphaValue = 1
        window.orderFrontRegardless()
        hideWork?.cancel()
        let work = DispatchWorkItem { [weak self] in
            NSAnimationContext.runAnimationGroup({ $0.duration = 0.3; self?.window.animator().alphaValue = 0 },
                                                 completionHandler: { self?.window.orderOut(nil) })
        }
        hideWork = work
        DispatchQueue.main.asyncAfter(deadline: .now() + Self.visibleSeconds, execute: work)
    }
}
