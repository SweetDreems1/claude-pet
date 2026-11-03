// Claude Pet — a small pixel Claude that walks along the bottom of the screen.
// Click it to make it jump, drag it anywhere, it falls back down. Menu bar icon → quit.
import AppKit

// MARK: - Sprite

let pixel: CGFloat = 6
let bodyColor = NSColor(calibratedRed: 0.85, green: 0.47, blue: 0.34, alpha: 1)   // Claude orange
let eyeColor = NSColor(calibratedRed: 0.17, green: 0.10, blue: 0.07, alpha: 1)

// X = body, E = eye, . = empty. Rows from top to bottom.
let bodyRows = [
    ".XXXXXXXXX.",
    ".XEXXXXXEX.",
    "XXXXXXXXXXX",
    ".XXXXXXXXX.",
    ".XXXXXXXXX.",
]
let blinkRow = ".XXXXXXXXX."
let blinkGap = "..........."
let legsStand = [".X.X...X.X.", ".X.X...X.X."]
let legsStepA = [".X.X...X.X.", "X...X.X...X"]
let legsStepB = ["..X.X.X.X..", "..X.X.X.X.."]
let legsSit = ["XX.X...X.XX"]
// Flattened body with legs sprawled out — the moment it hits the floor after a fall.
let splatRows = [
    ".XEXXXXXEX.",
    "XXXXXXXXXXX",
    "XXXXXXXXXXX",
    "XX.......XX",
]

let spriteColumns = 11
let spriteWidth = CGFloat(spriteColumns) * pixel

enum Mood { case walking, idle, sleeping, jumping, falling, dragged, climbing, perched, crouching, splat }

final class PetView: NSView {
    var facingLeft = false
    var mood: Mood = .idle
    var frameIndex = 0
    var blinking = false
    var bubble: String?
    /// Smaller pixels when sitting in a tight spot above a window.
    var pixelSize: CGFloat = pixel
    var nightcap = false   // dragged out of bed at night
    /// How many pixel rows above the head the cap still is while it drops on (0 = on the head).
    var capDrop = 0
    var happy = false      // being petted

    private static let palette: [Character: NSColor] = [
        "X": bodyColor, "E": eyeColor, "C": capColor, "W": capWhite, "P": capWhite,
    ]

    // Hover = petting.
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
        NSGraphicsContext.current?.shouldAntialias = false   // crisp pixel art
        NSColor.clear.setFill()
        dirtyRect.fill()

        var rows = bodyRows
        if happy {
            rows[1] = happyEyeRows[0]
            rows[2] = happyEyeRows[1]
        } else if blinking || mood == .sleeping {
            rows[1] = blinkRow
        }
        rows += legs()
        if mood == .splat { rows = splatRows }
        if nightcap && capDrop > 0 {
            // Cap falling onto the head: a gap of empty rows between cap and head, tip not flopped yet.
            rows = nightcapRows + Array(repeating: blinkGap, count: capDrop) + rows
        } else if nightcap {
            for tip in nightcapTip where tip.row < rows.count {
                var chars = Array(rows[tip.row])
                chars[tip.col] = tip.key
                rows[tip.row] = String(chars)
            }
            rows = nightcapRows + rows
        }

        let originX = (bounds.width - CGFloat(spriteColumns) * pixelSize) / 2
        let originY = bounds.height - CGFloat(rows.count) * pixelSize - 2
        for (rowIndex, row) in rows.enumerated() {
            for (colIndex, char) in row.enumerated() where char != "." {
                let col = facingLeft ? spriteColumns - 1 - colIndex : colIndex
                (PetView.palette[char] ?? bodyColor).setFill()
                // Round both edges so neighbouring pixels touch (no seams at in-between sizes).
                let x0 = (originX + CGFloat(col) * pixelSize).rounded()
                let x1 = (originX + CGFloat(col + 1) * pixelSize).rounded()
                let y0 = (originY + CGFloat(rowIndex) * pixelSize).rounded()
                let y1 = (originY + CGFloat(rowIndex + 1) * pixelSize).rounded()
                NSRect(x: x0, y: y0, width: x1 - x0, height: y1 - y0).fill()
            }
        }
        let spriteRect = NSRect(x: originX, y: originY,
                                width: CGFloat(spriteColumns) * pixelSize, height: CGFloat(rows.count) * pixelSize)
        drawBubble(around: spriteRect)
    }

    private func legs() -> [String] {
        switch mood {
        case .walking: return frameIndex % 2 == 0 ? legsStepA : legsStepB
        case .sleeping: return legsSit
        case .jumping, .falling, .dragged, .climbing: return legsStepB
        case .perched, .crouching, .splat: return legsSit   // crouching = squat before a jump
        case .idle: return legsStand
        }
    }

    /// Speech bubble above the pet, or beside it when the top of the screen is in the way.
    private func drawBubble(around sprite: NSRect) {
        guard let text = bubble else { return }
        let attributes: [NSAttributedString.Key: Any] = [
            .font: NSFont.monospacedSystemFont(ofSize: 15, weight: .bold),
            .foregroundColor: bodyColor,
        ]
        let size = text.size(withAttributes: attributes)
        let above = NSPoint(x: sprite.midX - size.width / 2 + (facingLeft ? -14 : 14),
                            y: sprite.minY - size.height - 2)
        let point = fitsOnScreen(NSRect(origin: above, size: size)) ? above : besidePoint(sprite, size)
        text.draw(at: point, withAttributes: attributes)
    }

    private func besidePoint(_ sprite: NSRect, _ size: NSSize) -> NSPoint {
        let y = sprite.midY - size.height / 2
        let right = NSPoint(x: sprite.maxX + 4, y: y)
        return fitsOnScreen(NSRect(origin: right, size: size)) ? right : NSPoint(x: sprite.minX - size.width - 4, y: y)
    }

    private func fitsOnScreen(_ rect: NSRect) -> Bool {
        guard let window, let screen = NSScreen.screens.first else { return true }
        let onScreen = window.convertToScreen(convert(rect, to: nil))
        return screen.frame.contains(onScreen) && bounds.contains(rect)
    }

    // Mouse: click = jump, drag = carry.
    var onClick: (() -> Void)?
    var onDrag: ((NSPoint) -> Void)?
    var onDrop: (() -> Void)?
    private var dragStart: NSPoint?
    private var dragged = false

    override func mouseDown(with event: NSEvent) {
        dragStart = event.locationInWindow
        dragged = false
    }

    override func mouseDragged(with event: NSEvent) {
        guard let start = dragStart, let window else { return }
        dragged = true
        let mouse = NSEvent.mouseLocation
        onDrag?(NSPoint(x: mouse.x - start.x, y: mouse.y - start.y))
        _ = window
    }

    override func mouseUp(with event: NSEvent) {
        if dragged { onDrop?() } else { onClick?() }
        dragStart = nil
    }
}

// MARK: - Behaviour

final class Pet {
    private let window: NSWindow
    private let view: PetView
    private var timer: Timer?

    private var velocityX: CGFloat = 0
    private var velocityY: CGFloat = 0
    private var moodTimeLeft: TimeInterval = 2
    private var tick = 0

    private let walkSpeed: CGFloat = 70        // px per second
    private static let homeRunSpeed: CGFloat = 170   // running home
    private static let homeHopHeight: CGFloat = 9
    private static let homeHopsPerSecond = 3.0
    private var hopPhase = 0.0
    private let gravity: CGFloat = -1800       // px per second²
    private let fps: Double = 30

    // Climbing onto the front window's close/minimise buttons.
    private var arcFrom = NSPoint.zero
    private var arcTo = NSPoint.zero
    private var arcElapsed: TimeInterval = 0
    private let arcDuration: TimeInterval = 0.9
    private let arcHeight: CGFloat = 140
    private var perch: PerchSpot?
    private var perchedSince = 0
    private static let perchBubbleTicks = 60   // "тут" bubble shows ~2 s
    private static let lookAroundTicks = 75    // every ~2.5 s maybe turn the other way
    private let spriteHeight = CGFloat(bodyRows.count + 2) * pixel + 2

    // Sleeps at home until woken; after a while awake it walks back home.
    private let houseWindow = makeOverlayWindow(size: HouseView.size, allDesktops: false)
    private var awakeTimeLeft: TimeInterval = 0
    private let awakeDuration: TimeInterval = 30
    private var returningHome = false
    private let launchGraceTicks = 60   // ~2 s

    // Short squat (wind-up) before every jump.
    private var crouchTicksLeft = 0
    private var afterCrouch: (() -> Void)?
    private var landingPixel = pixel
    private var targetPixel = pixel
    private var splatTicksLeft = 0
    private static let splatTicks = 18               // ~0.6 s lying flat
    private static let splatSpeed: CGFloat = -700    // falls faster than this land with a splat
    private static let sizeStepPerTick: CGFloat = 0.15   // 6 → 3 px in ~0.7 s
    private static let shrinkStartsAt = 0.6               // fraction of the jump arc
    private let recorder = Recorder()

    // Night: sleeps inside the house 00:00–08:00 MSK; can be pulled out by clicking the house.
    private var houseView: HouseView?
    private var insideHouse = false
    private static let pulledOutAwakeSeconds: TimeInterval = 20
    private static let nightCheckTicks = 30
    private var puttingOnCap = false
    private var afterCap: (() -> Void)?
    private var capSettledTick = 0
    private static let capDropRows = 7      // starts this many pixel rows above the head
    private static let capPauseTicks = 24   // ~0.8 s to "settle" in the cap before heading to bed

    // Petting (hover) and app-icon popups for new Dock badges.
    private var hovering = false
    private var hoverTicks = 0
    private var houseHovering = false
    private var houseHoverTicks = 0
    private static let petAfterTicks = 15   // ~0.5 s of hovering
    private let iconPopup = IconPopup()
    private var badgeWatcher: BadgeWatcher?

    // Desktop-switch robustness.
    private var lastSpaceChangeTick = -1000
    private var pendingClimb = false
    private var missingPerchTicks = 0
    private static let missingTicksBeforeFall = 20    // ≈ 0.7 s
    private static let crouchTicks = 5   // ~0.17 s
    private static let iconBubbleGap: CGFloat = 56   // leave room for "сижу" before the app icon

    init() {
        let size = NSSize(width: 170, height: 90)   // wide enough for a speech bubble at the side
        window = makeOverlayWindow(size: size)
        window.level = .statusBar   // can sit over the menu bar strip
        view = PetView(frame: NSRect(origin: .zero, size: size))
        window.contentView = view

        let houseView = HouseView(frame: NSRect(origin: .zero, size: HouseView.size))
        houseWindow.contentView = houseView
        houseView.onClick = { [weak self] in self?.houseClicked() }
        houseView.onHover = { [weak self] inside in self?.setHouseHovering(inside) }
        self.houseView = houseView
        placeHouse()
        houseWindow.orderFrontRegardless()

        window.setFrameOrigin(homeOrigin())
        window.orderFrontRegardless()
        fallAsleep()
        view.nightcap = Appearance.isDark

        view.onClick = { [weak self] in self?.jump() }
        view.onDrag = { [weak self] origin in self?.carry(to: origin) }
        view.onDrop = { [weak self] in self?.drop() }
        view.onHover = { [weak self] inside in self?.setHovering(inside) }

        // Dark / Light Mode switches.
        DistributedNotificationCenter.default().addObserver(
            forName: Notification.Name("AppleInterfaceThemeChangedNotification"), object: nil, queue: .main
        ) { [weak self] _ in
            // The app's appearance updates a moment after the notification.
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.3) { self?.appearanceChanged() }
        }

        badgeWatcher = BadgeWatcher { [weak self] app in self?.showNotification(from: app) }
        badgeWatcher?.start()

        // Desktop (Space) switched → hop onto the front window once it has settled.
        NSWorkspace.shared.notificationCenter.addObserver(
            forName: NSWorkspace.activeSpaceDidChangeNotification, object: nil, queue: .main
        ) { [weak self] _ in
            petLog("event: active space changed")
            self?.recorder.begin()
            self?.lastSpaceChangeTick = self?.tick ?? 0
            // Wait for the switch animation to finish, so the new desktop's windows are reported.
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.35) { self?.climbToFrontWindow() }
        }
    }

    static func screenArea() -> NSRect {
        // Always the main screen (the one with the menu bar), whatever window is active.
        (NSScreen.screens.first ?? NSScreen.main!).visibleFrame
    }

    func start() {
        timer = Timer.scheduledTimer(withTimeInterval: 1 / fps, repeats: true) { [weak self] _ in
            self?.step()
        }
    }

    func setVisible(_ visible: Bool) {
        visible ? houseWindow.orderFrontRegardless() : houseWindow.orderOut(nil)
        visible && !insideHouse ? window.orderFrontRegardless() : window.orderOut(nil)
    }

    private func placeHouse() {
        let area = Pet.screenArea()
        houseWindow.setFrameOrigin(NSPoint(x: area.minX + 4, y: area.minY))
    }

    /// Pet window origin right next to the house door.
    private func homeOrigin() -> NSPoint {
        let area = Pet.screenArea()
        let margin = (window.frame.width - spriteWidth) / 2
        return NSPoint(x: area.minX + 4 + HouseView.size.width - margin, y: area.minY)
    }

    private func fallAsleep() {
        returningHome = false
        view.mood = .sleeping
        view.facingLeft = false
        view.bubble = nil
        moodTimeLeft = .infinity
    }

    private func goHome() {
        // The house lives on the main desktop only; elsewhere just nap where we are.
        guard houseWindow.isOnActiveSpace else { return fallAsleep() }
        let homeX = homeOrigin().x
        if abs(window.frame.origin.x - homeX) < 3 { return fallAsleep() }
        returningHome = true
        hopPhase = 0
        view.bubble = ["ура!", "домой!", "бегу!"].randomElement()
        view.mood = .walking
        let speed = Night.isNight() ? Pet.homeRunSpeed * 0.6 : Pet.homeRunSpeed
        velocityX = (homeX < window.frame.origin.x ? -1 : 1) * speed
        if Night.isNight() { view.bubble = ["спать…", "в кроватку", "*зевает*"].randomElement() }
        view.facingLeft = velocityX < 0
        moodTimeLeft = .infinity
    }

    private func wake() {
        awakeTimeLeft = awakeDuration
        returningHome = false
    }

    private func step() {
        let dt = 1 / fps
        tick += 1
        let area = Pet.screenArea()
        var origin = window.frame.origin

        switch view.mood {
        case .walking:
            origin.x += velocityX * dt
            if tick % (returningHome ? 3 : 6) == 0 { view.frameIndex += 1 }
            if returningHome {
                // Happy little hops on the way home.
                hopPhase += dt * Pet.homeHopsPerSecond * .pi
                origin.y = area.minY + abs(sin(hopPhase)) * Pet.homeHopHeight
                if tick % 45 == 0 { view.bubble = nil }
            }
            let homeX = homeOrigin().x
            if returningHome, (velocityX < 0 && origin.x <= homeX) || (velocityX > 0 && origin.x >= homeX) {
                origin.x = homeX
                origin.y = area.minY
                Night.isNight() ? enterHouse() : fallAsleep()
                break
            }
            // The house is the left wall — except on the way home, when it may still be standing on the roof's side.
            let minX = returningHome ? min(homeX, origin.x) : homeX
            let maxX = area.maxX - window.frame.width + (window.frame.width - spriteWidth) / 2
            if origin.x < minX || origin.x > maxX {
                origin.x = min(max(origin.x, minX), maxX)
                // On the way home keep heading home; otherwise bounce off the edge.
                if !returningHome {
                    velocityX = -velocityX
                    view.facingLeft = velocityX < 0
                }
            }
        case .jumping, .falling:
            velocityY += gravity * dt
            origin.x += velocityX * dt
            origin.y += velocityY * dt
            if origin.y <= area.minY {
                origin.y = area.minY
                land()
            }
        case .splat:
            splatTicksLeft -= 1
            if splatTicksLeft <= 0 { getUp() }
        case .crouching:
            crouchTicksLeft -= 1
            if crouchTicksLeft <= 0 { afterCrouch?() }
        case .climbing:
            origin = stepArc(dt)
        case .perched:
            origin = stepPerched(dt, current: origin)
        case .idle, .sleeping, .dragged:
            break
        }

        if view.mood != .dragged { window.setFrameOrigin(origin) }
        recorder.capture(window, tick: tick)

        // Grow / shrink gradually instead of jumping between sizes.
        let sizeDelta = targetPixel - view.pixelSize
        view.pixelSize += max(-Pet.sizeStepPerTick, min(Pet.sizeStepPerTick, sizeDelta))

        if tick % Pet.nightCheckTicks == 0 { checkNight() }
        stepCapDrop()
        if tick % 15 == 0 { runDebugCommand() }
        stepPetting()
        if iconPopup.isShowing { placeIconPopup() }

        // Blink now and then.
        view.blinking = tick % 110 < 3
        if view.mood == .sleeping && !view.happy && tick % 20 == 0 {
            view.bubble = ["z", "zZ", "zZz"][(tick / 20) % 3]
        }

        if view.mood != .sleeping { awakeTimeLeft -= dt }
        moodTimeLeft -= dt
        if moodTimeLeft <= 0, [.walking, .idle, .sleeping].contains(view.mood) { pickNextMood() }
        view.needsDisplay = true
    }

    private func pickNextMood() {
        view.bubble = nil
        guard awakeTimeLeft > 0 else { return goHome() }
        if Double.random(in: 0..<1) < 0.6 {
            view.mood = .walking
            velocityX = (Bool.random() ? 1 : -1) * walkSpeed * (Night.isNight() ? 0.6 : 1)
            view.facingLeft = velocityX < 0
            moodTimeLeft = .random(in: 3...8)
        } else {
            view.mood = .idle
            moodTimeLeft = .random(in: 1.5...4)
        }
    }

    private func jump() {
        if view.mood == .perched { return hopDown() }
        guard [.walking, .idle, .sleeping].contains(view.mood) else { return }
        wake()
        crouch { [weak self] in
            guard let self else { return }
            view.mood = .jumping
            view.bubble = ["!", "хи", "♥", "?!"].randomElement()
            velocityY = 650
            velocityX = view.facingLeft ? -60 : 60
        }
    }

    private func crouch(then action: @escaping () -> Void) {
        view.bubble = nil
        view.mood = .crouching
        crouchTicksLeft = Pet.crouchTicks
        afterCrouch = action
    }

    // MARK: Climbing

    func climbToFrontWindow() {
        if insideHouse { return petLog("space changed: asleep inside the house") }
        guard [.walking, .idle, .sleeping, .perched].contains(view.mood) else {
            pendingClimb = true   // climb as soon as we land
            return petLog("space changed: busy (\(view.mood)), will climb after landing")
        }
        guard tick > launchGraceTicks else { return petLog("space changed: ignored at launch") }   // macOS sends a Space change right at launch
        // On the main desktop (where the house is) the pet doesn't climb: it jumps down and goes home.
        if houseWindow.isOnActiveSpace {
            petLog("space changed: main desktop, going home")
            if view.mood == .perched { fallDown() } else if awakeTimeLeft <= 0 { goHome() }
            return
        }
        // Nothing to climb on (empty desktop, full-screen window…): stay where we are.
        guard let spot = WindowFinder.frontPerch(), let placement = perchPlacement(for: spot) else {
            petLog("space changed: nothing to climb on (front app: \(NSWorkspace.shared.frontmostApplication?.localizedName ?? "?"))")
            if view.mood == .sleeping, houseWindow.isOnActiveSpace { goHome() }   // back on the main desktop
            return
        }
        petLog("space changed: climbing onto window \(spot.windowID) at \(spot.point)")
        perch = spot
        arcFrom = window.frame.origin
        arcTo = placement.origin
        landingPixel = placement.pixelSize
        arcElapsed = 0
        view.facingLeft = arcTo.x < arcFrom.x
        targetPixel = pixel   // full size for the jump; shrinks (if needed) while landing
        crouch { [weak self] in
            guard let self else { return }
            arcFrom = window.frame.origin
            view.bubble = "хоп"
            view.mood = .climbing
        }
    }

    /// Pixel sizes to try when sitting above a window: normal, then smaller if there is little room.
    static let perchPixelSizes: [CGFloat] = [pixel, 4, 3]

    /// Feet on the window's top edge, right above the close/minimise buttons. If the window is close to
    /// the top of the screen, the pet shrinks to fit; if even the smallest size doesn't fit, it sits at the very top.
    private func perchPlacement(for spot: PerchSpot) -> (origin: NSPoint, pixelSize: CGFloat)? {
        guard let screenTop = NSScreen.screens.first?.frame.maxY else { return nil }
        let x = spot.point.x - window.frame.width / 2
        let feetY = spot.point.y - 2
        // Body + one leg row, plus the nightcap when it's on — so the cap isn't cut off at the screen top.
        let rows = CGFloat(bodyRows.count + 1 + (view.nightcap ? nightcapRows.count : 0))
        for size in Pet.perchPixelSizes where feetY + rows * size + 2 <= screenTop {
            return (NSPoint(x: x, y: feetY), size)
        }
        let smallest = Pet.perchPixelSizes.last!
        return (NSPoint(x: x, y: screenTop - rows * smallest - 2), smallest)
    }

    private func stepArc(_ dt: TimeInterval) -> NSPoint {
        arcElapsed += dt
        let t = min(arcElapsed / arcDuration, 1)
        let x = arcFrom.x + (arcTo.x - arcFrom.x) * t
        let y = arcFrom.y + (arcTo.y - arcFrom.y) * t + arcHeight * 4 * t * (1 - t)
        if t > Pet.shrinkStartsAt { targetPixel = landingPixel }   // start shrinking on the way down
        if t >= 1 {
            view.mood = .perched
            view.bubble = ["тут", "сижу", ":)"].randomElement()
            perchedSince = tick
        }
        return NSPoint(x: x, y: y)
    }

    /// Sits on the window until clicked, dragged, or the window closes / leaves the screen.
    /// Rides along when the window moves — including when the whole desktop slides away during a
    /// switch; once its "ground" leaves the screen, it falls.
    private func stepPerched(_ dt: TimeInterval, current: NSPoint) -> NSPoint {
        if tick - perchedSince > Pet.perchBubbleTicks { view.bubble = nil }
        // Look around now and then so it doesn't just sit there like a statue.
        if tick % Pet.lookAroundTicks == 0, Bool.random() { view.facingLeft.toggle() }

        guard let id = perch?.windowID, let spot = WindowFinder.perch(for: id),
              let placement = perchPlacement(for: spot) else {
            // During a desktop switch the window briefly looks hidden — don't fall for that right away.
            missingPerchTicks += 1
            if missingPerchTicks >= Pet.missingTicksBeforeFall { fallDown() }
            return current
        }
        missingPerchTicks = 0

        let screen = NSScreen.screens.first?.frame ?? .zero
        let margin = (window.frame.width - spriteWidth) / 2
        let spriteLeft = placement.origin.x + margin
        if spriteLeft < screen.minX || spriteLeft + spriteWidth > screen.maxX {
            fallDown()   // the window slid out from under its feet
            return NSPoint(x: min(max(placement.origin.x, screen.minX - margin),
                                  screen.maxX - spriteWidth - margin), y: current.y)
        }
        targetPixel = placement.pixelSize
        return placement.origin
    }

    /// Drops straight down from where it sits (no hop) — lands with a splat.
    private func fallDown() {
        perch = nil
        targetPixel = pixel
        view.bubble = nil
        view.mood = .falling
        velocityX = 0
        velocityY = 0
    }

    private func hopDown() {
        perch = nil
        targetPixel = pixel
        view.bubble = nil
        view.mood = .falling
        velocityY = 300
        velocityX = view.facingLeft ? -80 : 80
    }

    /// Test hook: write "snap", "pull" or "notify" into rec/CMD (only used while debugging).
    private func runDebugCommand() {
        let url = Recorder.folder.appendingPathComponent("CMD")
        guard let command = try? String(contentsOf: url, encoding: .utf8) else { return }
        try? FileManager.default.removeItem(at: url)
        switch command.trimmingCharacters(in: .whitespacesAndNewlines) {
        case "snap": recorder.begin()
        case "pull": houseClicked()
        case "notify":
            if let app = NSRunningApplication.runningApplications(withBundleIdentifier: "ru.keepcoder.Telegram").first {
                showNotification(from: app)
            }
        case "dark": appearanceChanged(forcedDark: true)
        case "light": appearanceChanged(forcedDark: false)
        case "pet": setHovering(true)
        case "unpet": setHovering(false)
        default: break
        }
    }

    // MARK: Night

    private func checkNight() {
        guard Night.isNight() else {
            if insideHouse { leaveHouse() }
            return
        }
        // Bedtime: once it's resting, it goes home and inside.
        if !insideHouse, !puttingOnCap, view.mood == .sleeping { bedtime() }
    }

    // MARK: Dark Mode nightcap

    private var wasDark = Appearance.isDark

    /// Called when the system appearance changes: Dark → the cap drops on, Light → it comes off.
    private func appearanceChanged(forcedDark: Bool? = nil) {
        let dark = forcedDark ?? Appearance.isDark
        guard dark != wasDark else { return }
        wasDark = dark
        petLog("appearance: \(dark ? "dark" : "light")")
        if dark {
            if insideHouse || !window.isVisible { view.nightcap = true; return }
            if !view.nightcap, !puttingOnCap, [.sleeping, .idle, .walking, .perched].contains(view.mood) {
                let previousMood = view.mood
                putOnCap { [weak self] in self?.resume(previousMood) }
            } else {
                view.nightcap = true
            }
        } else {
            view.nightcap = false
            view.capDrop = 0
            if window.isVisible, !insideHouse { view.bubble = "утро!" }
        }
    }

    /// Back to what it was doing before the cap dropped on.
    private func resume(_ mood: Mood) {
        switch mood {
        case .perched: view.mood = .perched
        case .sleeping: fallAsleep()
        default:
            view.mood = .idle
            moodTimeLeft = 1
        }
    }

    private func putOnCap(then action: @escaping () -> Void) {
        puttingOnCap = true
        returningHome = false
        if view.mood != .perched { view.mood = .idle }
        moodTimeLeft = .infinity
        view.bubble = nil
        view.nightcap = true
        view.capDrop = Pet.capDropRows
        afterCap = action
    }

    private func stepCapDrop() {
        guard puttingOnCap, tick % 2 == 0 else { return }
        if view.capDrop > 0 {
            view.capDrop -= 1
            if view.capDrop == 0 {
                capSettledTick = tick
                view.bubble = "*зевает*"
            }
        } else if tick - capSettledTick > Pet.capPauseTicks {
            puttingOnCap = false
            view.bubble = nil
            afterCap?()
            afterCap = nil
        }
    }

    /// Into the house if at the door, otherwise walk home first (only the main desktop has the house).
    private func bedtime() {
        guard houseWindow.isOnActiveSpace else { return fallAsleep() }
        abs(window.frame.origin.x - homeOrigin().x) < 3 ? enterHouse() : goHome()
    }

    private func enterHouse() {
        petLog("night: going inside the house")
        insideHouse = true
        returningHome = false
        view.bubble = nil
        view.mood = .sleeping
        moodTimeLeft = .infinity
        window.orderOut(nil)
        iconPopup.window.orderOut(nil)
        houseView?.lightsOn = false
    }

    private func leaveHouse() {
        petLog("morning: coming out of the house")
        insideHouse = false
        view.nightcap = Appearance.isDark
        houseView?.lightsOn = true
        houseView?.showHeart = false
        window.setFrameOrigin(homeOrigin())
        window.orderFrontRegardless()
        fallAsleep()
    }

    private func houseClicked() {
        guard insideHouse else { return jump() }
        // Pulled out of bed: sleepy, in a nightcap, back inside in a little while.
        insideHouse = false
        houseView?.lightsOn = true
        houseView?.showHeart = false
        view.nightcap = true
        targetPixel = pixel
        window.setFrameOrigin(homeOrigin())
        window.orderFrontRegardless()
        awakeTimeLeft = Pet.pulledOutAwakeSeconds
        returningHome = false
        view.mood = .idle
        view.bubble = ["ммм?", "*зевает*", "чего…"].randomElement()
        moodTimeLeft = 2
    }

    // MARK: Petting & notifications

    private func setHovering(_ inside: Bool) {
        hovering = inside
        hoverTicks = 0
        if !inside, view.happy {
            view.happy = false
            if view.bubble == "♥" { view.bubble = nil }
        }
    }

    /// Petting works only at home: next to the house (asleep or standing), or the house itself when it's inside.
    private var isAtHome: Bool {
        houseWindow.isOnActiveSpace && abs(window.frame.origin.x - homeOrigin().x) < 4
            && [.idle, .sleeping].contains(view.mood)
    }

    private func stepPetting() {
        // The house: pet it while the pet sleeps inside.
        if houseHovering, insideHouse {
            houseHoverTicks += 1
            houseView?.showHeart = houseHoverTicks >= Pet.petAfterTicks
        }
        if view.happy && !isAtHome {   // walked/jumped away from home: petting is over
            view.happy = false
            if view.bubble == "♥" { view.bubble = nil }
        }
        guard hovering, !insideHouse, isAtHome else { return }
        hoverTicks += 1
        guard hoverTicks >= Pet.petAfterTicks else { return }
        if !view.happy {
            // One petting = one steady ♥ until the cursor leaves.
            view.happy = true
            view.bubble = "♥"
        }
        moodTimeLeft = max(moodTimeLeft, 1)
    }

    private func setHouseHovering(_ inside: Bool) {
        houseHovering = inside
        houseHoverTicks = 0
        if !inside { houseView?.showHeart = false }
    }

    private func showNotification(from app: NSRunningApplication) {
        guard !insideHouse, window.isVisible else { return }
        petLog("badge: \(app.localizedName ?? "?")")
        iconPopup.show(app.icon)
        placeIconPopup()
    }

    /// App icon just left of where the speech bubble shows — above the pet's head, or beside it at the screen top.
    private func placeIconPopup() {
        let size = IconPopup.size
        let margin = (window.frame.width - CGFloat(spriteColumns) * view.pixelSize) / 2
        let spriteLeft = window.frame.minX + margin
        let headTop = window.frame.minY + 2 + CGFloat(bodyRows.count + 2 + (view.nightcap ? nightcapRows.count : 0)) * view.pixelSize
        let screen = NSScreen.screens.first?.frame ?? .zero
        var origin: NSPoint
        if [.perched, .climbing].contains(view.mood) {
            // Sitting on an app window (near the top of the screen): show it to the right, past the speech bubble.
            let spriteRight = spriteLeft + CGFloat(spriteColumns) * view.pixelSize
            let bubbleRoom: CGFloat = view.bubble == nil ? 6 : Pet.iconBubbleGap
            origin = NSPoint(x: spriteRight + bubbleRoom,
                             y: min(window.frame.minY + 2, screen.maxY - size.height))
        } else {
            origin = NSPoint(x: spriteLeft - size.width / 2, y: headTop + 4)
            if origin.y + size.height > screen.maxY {
                origin = NSPoint(x: spriteLeft - size.width - 6, y: headTop - size.height)
            }
        }
        origin.x = min(max(origin.x, screen.minX), screen.maxX - size.width)
        iconPopup.window.setFrameOrigin(origin)
    }

    private func getUp() {
        view.bubble = nil
        view.mood = .idle
        moodTimeLeft = 0.8
        if pendingClimb {
            pendingClimb = false
            climbToFrontWindow()
        }
    }

    private func carry(to origin: NSPoint) {
        perch = nil
        targetPixel = pixel
        wake()
        view.mood = .dragged
        view.bubble = "!!"
        window.setFrameOrigin(origin)
    }

    private func drop() {
        view.mood = .falling
        velocityX = 0
        velocityY = 0
    }

    private func land() {
        let hardLanding = velocityY < Pet.splatSpeed
        view.bubble = nil
        velocityY = 0
        velocityX = 0
        if hardLanding {
            view.mood = .splat
            view.bubble = ["ой", "уф", "бдыщ"].randomElement()
            splatTicksLeft = Pet.splatTicks
            return
        }
        view.mood = .idle
        moodTimeLeft = 1
        if pendingClimb {
            pendingClimb = false
            climbToFrontWindow()
        }
    }
}

// MARK: - App

final class AppDelegate: NSObject, NSApplicationDelegate {
    private var pet: Pet?
    private var statusItem: NSStatusItem?
    private var visible = true

    func applicationDidFinishLaunching(_ notification: Notification) {
        let pet = Pet()
        pet.start()
        self.pet = pet

        let item = NSStatusBar.system.statusItem(withLength: NSStatusItem.variableLength)
        item.button?.title = "✳︎"
        let menu = NSMenu()
        menu.addItem(NSMenuItem(title: "Спрятать / показать", action: #selector(toggle), keyEquivalent: "h"))
        menu.addItem(.separator())
        menu.addItem(NSMenuItem(title: "Выйти", action: #selector(quit), keyEquivalent: "q"))
        menu.items.forEach { $0.target = self }
        item.menu = menu
        statusItem = item
    }

    @objc private func toggle() {
        visible.toggle()
        pet?.setVisible(visible)
    }

    @objc private func quit() { NSApp.terminate(nil) }
}

let app = NSApplication.shared
let delegate = AppDelegate()
app.delegate = delegate
app.setActivationPolicy(.accessory)   // no Dock icon
app.run()

/// Tiny debug log next to the app: ~/telegram-bot/claude-pet/pet.log
func petLog(_ message: String) {
    let url = URL(fileURLWithPath: NSHomeDirectory()).appendingPathComponent("telegram-bot/claude-pet/pet.log")
    let line = "\(Date()) \(message)\n"
    guard let data = line.data(using: .utf8) else { return }
    if let handle = try? FileHandle(forWritingTo: url) {
        handle.seekToEndOfFile()
        handle.write(data)
        try? handle.close()
    } else {
        try? data.write(to: url)
    }
}
