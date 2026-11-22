import Foundation
import Darwin

struct DeckState: Codable {
    var wifi = false, bluetooth = false, dark = false
    var volume = 0.0, brightness = 0.5
    var title: String?, artist: String?
    var playing = false
    var art: Data?

    /// Real home folder (inside the widget sandbox NSHomeDirectory() points at its container instead).
    static var dir: URL {
        let home = getpwuid(getuid()).map { String(cString: $0.pointee.pw_dir) } ?? NSHomeDirectory()
        return URL(fileURLWithPath: home).appendingPathComponent(".controldeck")
    }

    /// Widget reads (allowed by a read-only sandbox exception for ~/.controldeck/).
    static func load() -> DeckState {
        guard let d = try? Data(contentsOf: dir.appendingPathComponent("state.json")),
              let s = try? JSONDecoder().decode(DeckState.self, from: d) else { return DeckState() }
        return s
    }
    /// Same as load(), but also returns a short reason when reading fails (shown in the widget for debugging).
    static func loadResult() -> (DeckState, String?) {
        let url = dir.appendingPathComponent("state.json")
        do {
            let d = try Data(contentsOf: url)
            return (try JSONDecoder().decode(DeckState.self, from: d), nil)
        } catch {
            return (DeckState(), "\(url.path): \(error.localizedDescription)")
        }
    }
    /// Helper app writes.
    func save() -> Bool {
        try? FileManager.default.createDirectory(at: Self.dir, withIntermediateDirectories: true)
        do { try JSONEncoder().encode(self).write(to: Self.dir.appendingPathComponent("state.json")); return true }
        catch { return false }
    }
}
