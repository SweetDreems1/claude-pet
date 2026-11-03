// Little pixel house in the bottom-left corner where the pet sleeps.
import AppKit

final class HouseView: NSView {
    static let rows = [
        "..........cc.",
        "......RR..cc.",
        ".....RRRR.cc.",
        "....RRRRRRcc.",
        "...RRRRRRRRR.",
        "..RRRRRRRRRRR",
        ".RRRRRRRRRRRR",
        "..WWWWWWWWWW.",
        "..WggWWWWDDW.",
        "..WggWWWWDDW.",
        "..WWWWWWWDdW.",
        "..WWWWWWWDDW.",
    ]
    /// Room above the roof for a ♥ when you pet the house while the pet sleeps inside.
    static let heartPad: CGFloat = 22
    static let size = NSSize(width: CGFloat(rows[0].count) * pixel, height: CGFloat(rows.count) * pixel + heartPad)

    private static let palette: [Character: NSColor] = [
        "R": NSColor(calibratedRed: 0.55, green: 0.25, blue: 0.18, alpha: 1),   // roof
        "c": NSColor(calibratedRed: 0.40, green: 0.36, blue: 0.34, alpha: 1),   // chimney
        "W": NSColor(calibratedRed: 0.96, green: 0.90, blue: 0.80, alpha: 1),   // walls
        "g": NSColor(calibratedRed: 1.00, green: 0.85, blue: 0.45, alpha: 1),   // lit window
        "D": NSColor(calibratedRed: 0.42, green: 0.26, blue: 0.16, alpha: 1),   // door
        "d": NSColor(calibratedRed: 0.95, green: 0.75, blue: 0.30, alpha: 1),   // door knob
    ]

    var onClick: (() -> Void)?
    /// Window light; off while the pet is asleep inside at night.
    var lightsOn = true { didSet { needsDisplay = true } }
    private static let darkWindow = NSColor(calibratedRed: 0.20, green: 0.22, blue: 0.32, alpha: 1)
    var showHeart = false { didSet { if showHeart != oldValue { needsDisplay = true } } }

    var onHover: ((Bool) -> Void)?
    override func updateTrackingAreas() {
        super.updateTrackingAreas()
        trackingAreas.forEach(removeTrackingArea)
        addTrackingArea(NSTrackingArea(rect: bounds, options: [.mouseEnteredAndExited, .activeAlways, .inVisibleRect],
                                       owner: self, userInfo: nil))
    }
    override func mouseEntered(with event: NSEvent) { onHover?(true) }
    override func mouseExited(with event: NSEvent) { onHover?(false) }

    override var isFlipped: Bool { true }

    override func draw(_ dirtyRect: NSRect) {
        for (rowIndex, row) in Self.rows.enumerated() {
            for (colIndex, char) in row.enumerated() {
                guard var color = Self.palette[char] else { continue }
                if char == "g" && !lightsOn { color = Self.darkWindow }
                color.setFill()
                NSRect(x: CGFloat(colIndex) * pixel, y: Self.heartPad + CGFloat(rowIndex) * pixel,
                       width: pixel, height: pixel).fill()
            }
        }
        if showHeart {
            let attributes: [NSAttributedString.Key: Any] = [
                .font: NSFont.monospacedSystemFont(ofSize: 15, weight: .bold), .foregroundColor: bodyColor,
            ]
            let heart = "♥" as NSString
            let size = heart.size(withAttributes: attributes)
            heart.draw(at: NSPoint(x: (bounds.width - size.width) / 2 - 6, y: Self.heartPad - size.height), withAttributes: attributes)
        }
    }

    override func mouseUp(with event: NSEvent) { onClick?() }
}

func makeOverlayWindow(size: NSSize, allDesktops: Bool = true) -> NSWindow {
    let window = NSWindow(contentRect: NSRect(origin: .zero, size: size),
                          styleMask: .borderless, backing: .buffered, defer: false)
    window.isOpaque = false
    window.backgroundColor = .clear
    window.hasShadow = false
    window.level = .floating
    // The house stays on the desktop it was opened on; the pet follows you to every desktop.
    window.collectionBehavior = allDesktops ? [.canJoinAllSpaces, .stationary, .fullScreenAuxiliary] : [.stationary]
    return window
}
