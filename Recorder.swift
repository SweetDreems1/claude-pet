// Debug recorder: while ~/telegram-bot/claude-pet/rec/ON exists, saves a few seconds of frames
// (the pet's own window as PNG + its position on screen) after each desktop switch.
import AppKit

final class Recorder {
    static let folder = URL(fileURLWithPath: NSHomeDirectory()).appendingPathComponent("telegram-bot/claude-pet/rec")
    private static let framesPerRecording = 60   // every 2nd tick at 30 fps → 4 s

    private var framesLeft = 0
    private var index = 0

    var isEnabled: Bool {
        FileManager.default.fileExists(atPath: Recorder.folder.appendingPathComponent("ON").path)
    }

    func begin() {
        guard isEnabled else { return }
        framesLeft = Recorder.framesPerRecording   // frames keep numbering across switches
        append("# switch\n")
    }

    func capture(_ window: NSWindow, tick: Int) {
        guard framesLeft > 0, tick % 2 == 0, let view = window.contentView,
              let rep = view.bitmapImageRepForCachingDisplay(in: view.bounds) else { return }
        view.cacheDisplay(in: view.bounds, to: rep)
        guard let png = rep.representation(using: .png, properties: [:]) else { return }
        let name = String(format: "frame_%03d.png", index)
        try? png.write(to: Recorder.folder.appendingPathComponent(name))
        let f = window.frame
        append("\(name) \(f.minX) \(f.minY) \(f.width) \(f.height)\n")
        index += 1
        framesLeft -= 1
    }

    private func append(_ line: String) {
        let url = Recorder.folder.appendingPathComponent("frames.txt")
        guard let data = line.data(using: .utf8) else { return }
        if let handle = try? FileHandle(forWritingTo: url) {
            handle.seekToEndOfFile()
            handle.write(data)
            try? handle.close()
        } else {
            try? data.write(to: url)
        }
    }
}
