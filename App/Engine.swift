import AppKit
import WidgetKit

extension NSImage {
    func jpeg(_ side: CGFloat) -> Data? {
        let img = NSImage(size: NSSize(width: side, height: side))
        img.lockFocus(); draw(in: NSRect(x: 0, y: 0, width: side, height: side)); img.unlockFocus()
        guard let t = img.tiffRepresentation, let r = NSBitmapImageRep(data: t) else { return nil }
        return r.representation(using: .jpeg, properties: [.compressionFactor: 0.8])
    }
}

/// Background helper: publishes system state to the widget and performs widget taps (controldeck://action).
@MainActor
final class Engine {
    private var last: Data?
    private var artKey = ""
    private var artData: Data?

    func start() {
        tick()
        Timer.scheduledTimer(withTimeInterval: 2, repeats: true) { [weak self] _ in
            Task { @MainActor in self?.tick() }
        }
    }

    func tick() {
        var s = DeckState()
        s.wifi = Toggles.wifi(); s.bluetooth = Toggles.bluetooth(); s.dark = Toggles.dark()
        s.volume = Double(Audio.volume()); s.brightness = Double(Brightness.get() ?? 0.5)
        if let t = NowPlaying.current() {
            s.title = t.title; s.artist = t.artist; s.playing = t.playing
            let key = t.app + t.title + t.artist
            if key != artKey { artKey = key; artData = nil; fetchArt(t) }
            s.art = artData
        } else { artKey = ""; artData = nil }
        let d = try? JSONEncoder().encode(s)
        guard d != last else { return }
        guard s.save() else { return }   // widget not added yet; retry next tick
        last = d
        WidgetCenter.shared.reloadAllTimelines()
    }

    private func fetchArt(_ t: Track) {
        if t.app == "Music" { artData = NowPlaying.musicArt()?.jpeg(120) }
        else if let u = NowPlaying.spotifyArtURL() {
            Task.detached {
                let d = (try? Data(contentsOf: u)).flatMap { NSImage(data: $0) }?.jpeg(120)
                await MainActor.run { self.artData = d; self.last = nil; self.tick() }
            }
        }
    }

    func handle(_ url: URL) {
        let step = 0.0625
        func player(_ cmd: String) { if let t = NowPlaying.current() { NowPlaying.send(cmd, app: t.app) } }
        switch url.host {
        case "wifi": Toggles.setWifi(!Toggles.wifi())
        case "bluetooth": Toggles.setBluetooth(!Toggles.bluetooth())
        case "dark": Toggles.setDark(!Toggles.dark())
        case "volup": Audio.setVolume(Audio.volume() + Float(step))
        case "voldown": Audio.setVolume(Audio.volume() - Float(step))
        case "brightup": Brightness.set((Brightness.get() ?? 0.5) + Float(step))
        case "brightdown": Brightness.set((Brightness.get() ?? 0.5) - Float(step))
        case "play": player("playpause")
        case "next": player("next track")
        case "prev": player("previous track")
        case "quit": NSApp.terminate(nil); return
        default: return
        }
        for d in [0.3, 1.5] { DispatchQueue.main.asyncAfter(deadline: .now() + d) { self.tick() } }
    }
}
