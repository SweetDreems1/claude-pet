// Finds the front window of the active app and where its close/minimise buttons are.
import AppKit

struct PerchSpot {
    let windowID: CGWindowID
    /// Point (Cocoa coordinates, origin bottom-left) right above the traffic-light buttons.
    let point: NSPoint
}

enum WindowFinder {
    /// Roughly the middle of the close / minimise / zoom buttons, measured from the window's left edge.
    static let buttonsCenterOffset: CGFloat = 36
    static let minWindowSize = CGSize(width: 200, height: 120)

    /// The front normal window of the frontmost app on the main screen, or nil (desktop, our own app, etc).
    static func frontPerch() -> PerchSpot? {
        guard let app = NSWorkspace.shared.frontmostApplication,
              app.processIdentifier != getpid() else { return nil }
        let options: CGWindowListOption = [.optionOnScreenOnly, .excludeDesktopElements]
        guard let windows = CGWindowListCopyWindowInfo(options, kCGNullWindowID) as? [[String: Any]] else { return nil }

        // The list is ordered front to back, so the first match is the app's front window.
        for info in windows {
            guard (info[kCGWindowOwnerPID as String] as? pid_t) == app.processIdentifier,
                  (info[kCGWindowLayer as String] as? Int) == 0,
                  let id = info[kCGWindowNumber as String] as? CGWindowID,
                  let frame = cgFrame(info),
                  frame.width >= minWindowSize.width, frame.height >= minWindowSize.height
            else { continue }
            return spot(for: id, frame: frame)
        }
        return nil
    }

    /// The front-most window right under the pet's feet (or below them) when it is dropped at `x`,
    /// with the drop point measured from that window's left edge.
    static func spotUnder(x: CGFloat, feetY: CGFloat) -> (spot: PerchSpot, offset: CGFloat)? {
        guard let main = NSScreen.screens.first,
              let windows = CGWindowListCopyWindowInfo([.optionOnScreenOnly, .excludeDesktopElements], kCGNullWindowID) as? [[String: Any]]
        else { return nil }
        for info in windows {
            guard (info[kCGWindowOwnerPID as String] as? pid_t) != getpid(),
                  (info[kCGWindowLayer as String] as? Int) == 0,
                  let id = info[kCGWindowNumber as String] as? CGWindowID,
                  let frame = cgFrame(info),
                  frame.width >= minWindowSize.width, frame.height >= minWindowSize.height,
                  x >= frame.minX, x <= frame.maxX,
                  feetY >= main.frame.maxY - frame.maxY   // window bottom (Cocoa) is under the feet
            else { continue }
            let offset = x - frame.minX
            return spot(for: id, frame: frame, offset: offset).map { ($0, offset) }
        }
        return nil
    }

    /// Current perch point of a window we are sitting on; nil if it closed or went off screen.
    static func perch(for windowID: CGWindowID, offset: CGFloat = buttonsCenterOffset) -> PerchSpot? {
        guard let list = CGWindowListCopyWindowInfo(.optionIncludingWindow, windowID) as? [[String: Any]],
              let info = list.first,
              (info[kCGWindowIsOnscreen as String] as? Bool) == true,
              let frame = cgFrame(info)
        else { return nil }
        return spot(for: windowID, frame: frame, offset: offset)
    }

    private static func cgFrame(_ info: [String: Any]) -> CGRect? {
        guard let bounds = info[kCGWindowBounds as String] as? NSDictionary else { return nil }
        return CGRect(dictionaryRepresentation: bounds as CFDictionary)
    }

    /// CoreGraphics measures from the top-left of the main screen; Cocoa from the bottom-left.
    private static func spot(for id: CGWindowID, frame: CGRect, offset: CGFloat = buttonsCenterOffset) -> PerchSpot? {
        guard let main = NSScreen.screens.first else { return nil }
        let top = main.frame.maxY - frame.minY
        let point = NSPoint(x: frame.minX + offset, y: top)
        return main.frame.contains(NSPoint(x: point.x, y: top - 1)) ? PerchSpot(windowID: id, point: point) : nil
    }
}
