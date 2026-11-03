// Night time (Moscow) and the floppy nightcap the pet wears when it's dragged out of bed.
import AppKit

enum Night {
    static let timeZone = TimeZone(identifier: "Europe/Moscow")!
    static let startHour = 0   // goes to bed at 00:00
    static let endHour = 8     // comes out at 08:00

    /// For testing: while this file exists it is always night.
    static let forceNightFile = URL(fileURLWithPath: NSHomeDirectory()).appendingPathComponent("telegram-bot/claude-pet/FORCE_NIGHT")

    static func isNight(_ date: Date = Date()) -> Bool {
        if FileManager.default.fileExists(atPath: forceNightFile.path) { return true }
        var calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = timeZone
        let hour = calendar.component(.hour, from: date)
        return hour >= startHour && hour < endHour
    }
}

/// Nightcap drawn above the head; the tip flops over to the side with a pom-pom.
/// C = cap, W = white brim, P = pom-pom.
let nightcapRows = [
    "...CCC.....",
    "..CCCCCC...",
    ".WWWWWWWCC.",
]
/// The cap's tip flops down beside the head: (row of the body, column, colour key).
let nightcapTip: [(row: Int, col: Int, key: Character)] = [(0, 10, "C"), (1, 10, "P")]
let capColor = NSColor(calibratedRed: 0.36, green: 0.45, blue: 0.80, alpha: 1)
let capWhite = NSColor(calibratedWhite: 0.97, alpha: 1)

/// Body rows 1–2 when being petted: eyes squeezed into happy ^ ^.
let happyEyeRows = [
    ".XEXXXXXEX.",
    "XEXEXXXEXEX",
]
