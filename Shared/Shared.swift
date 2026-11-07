import Foundation

struct DeckState: Codable {
    var wifi = false, bluetooth = false, dark = false
    var volume = 0.0, brightness = 0.5
    var title: String?, artist: String?
    var playing = false
    var art: Data?

    static let widgetID = "com.olayemi.controldeck.widget"

    /// Widget (sandboxed) reads from its own container.
    static func load() -> DeckState {
        let u = FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask)[0]
            .appendingPathComponent("state.json")
        guard let d = try? Data(contentsOf: u), let s = try? JSONDecoder().decode(DeckState.self, from: d) else { return DeckState() }
        return s
    }
    /// Helper app (unsandboxed) writes into the widget's container, once macOS has created it.
    func save() -> Bool {
        let base = URL(fileURLWithPath: NSHomeDirectory()).appendingPathComponent("Library/Containers/\(Self.widgetID)/Data")
        guard FileManager.default.fileExists(atPath: base.path) else { return false }
        let dir = base.appendingPathComponent("Library/Application Support")
        try? FileManager.default.createDirectory(at: dir, withIntermediateDirectories: true)
        do { try JSONEncoder().encode(self).write(to: dir.appendingPathComponent("state.json")); return true }
        catch { return false }
    }
}
