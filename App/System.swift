import AppKit
import CoreAudio
import CoreGraphics
import CoreWLAN
import IOBluetooth

// MARK: Volume (CoreAudio, public API)
enum Audio {
    private static func output() -> AudioDeviceID? {
        var id = AudioDeviceID(0)
        var size = UInt32(MemoryLayout<AudioDeviceID>.size)
        var a = AudioObjectPropertyAddress(mSelector: kAudioHardwarePropertyDefaultOutputDevice,
                                           mScope: kAudioObjectPropertyScopeGlobal,
                                           mElement: kAudioObjectPropertyElementMain)
        let s = AudioObjectGetPropertyData(AudioObjectID(kAudioObjectSystemObject), &a, 0, nil, &size, &id)
        return s == noErr ? id : nil
    }
    // 'vmvc' = virtual main volume, the same scalar the system volume keys use
    private static var addr: AudioObjectPropertyAddress {
        AudioObjectPropertyAddress(mSelector: 0x766D7663, mScope: kAudioDevicePropertyScopeOutput,
                                   mElement: kAudioObjectPropertyElementMain)
    }
    static func volume() -> Float {
        guard let d = output() else { return 0 }
        var v: Float32 = 0; var size = UInt32(MemoryLayout<Float32>.size); var a = addr
        return AudioObjectGetPropertyData(d, &a, 0, nil, &size, &v) == noErr ? v : 0
    }
    static func setVolume(_ v: Float) {
        guard let d = output() else { return }
        var val = max(0, min(1, v)); var a = addr
        AudioObjectSetPropertyData(d, &a, 0, nil, UInt32(MemoryLayout<Float32>.size), &val)
    }
}

// MARK: Brightness (private DisplayServices; built-in display only, not App Store safe)
enum Brightness {
    private typealias GetFn = @convention(c) (CGDirectDisplayID, UnsafeMutablePointer<Float>) -> Int32
    private typealias SetFn = @convention(c) (CGDirectDisplayID, Float) -> Int32
    private static let lib = dlopen("/System/Library/PrivateFrameworks/DisplayServices.framework/DisplayServices", RTLD_LAZY)

    static func get() -> Float? {
        guard let l = lib, let s = dlsym(l, "DisplayServicesGetBrightness") else { return nil }
        var v: Float = 0
        return unsafeBitCast(s, to: GetFn.self)(CGMainDisplayID(), &v) == 0 ? v : nil
    }
    static func set(_ v: Float) {
        guard let l = lib, let s = dlsym(l, "DisplayServicesSetBrightness") else { return }
        _ = unsafeBitCast(s, to: SetFn.self)(CGMainDisplayID(), max(0, min(1, v)))
    }
}

// MARK: Now Playing (AppleScript to Music / Spotify)
struct Track { var title: String; var artist: String; var playing: Bool; var app: String }

enum NowPlaying {
    static func run(_ src: String) -> String? {
        var err: NSDictionary?
        let r = NSAppleScript(source: src)?.executeAndReturnError(&err)
        return err == nil ? (r?.stringValue ?? "") : nil
    }
    private static func isRunning(_ app: String) -> Bool {
        NSWorkspace.shared.runningApplications.contains { $0.localizedName == app }
    }
    static func current() -> Track? {
        for app in ["Music", "Spotify"] where isRunning(app) {
            let src = """
            tell application "\(app)"
              if player state is stopped then return ""
              return (name of current track) & "||" & (artist of current track) & "||" & (player state as string)
            end tell
            """
            guard let out = run(src), !out.isEmpty else { continue }
            let p = out.components(separatedBy: "||")
            if p.count == 3 { return Track(title: p[0], artist: p[1], playing: p[2] == "playing", app: app) }
        }
        return nil
    }
    static func send(_ command: String, app: String) { _ = run("tell application \"\(app)\" to \(command)") }

    static func musicArt() -> NSImage? {
        let path = NSTemporaryDirectory() + "controldeck_art"
        try? FileManager.default.removeItem(atPath: path)
        _ = run("""
        tell application "Music"
          set d to (data of artwork 1 of current track)
          set f to open for access POSIX file "\(path)" with write permission
          set eof f to 0
          write d to f
          close access f
        end tell
        """)
        return NSImage(contentsOfFile: path)
    }
    static func spotifyArtURL() -> URL? {
        run("tell application \"Spotify\" to return artwork url of current track").flatMap(URL.init(string:))
    }
}

// MARK: Toggles
@_silgen_name("IOBluetoothPreferenceGetControllerPowerState") private func btGet() -> Int32
@_silgen_name("IOBluetoothPreferenceSetControllerPowerState") private func btSet(_ s: Int32)

enum Toggles {
    static func wifi() -> Bool { CWWiFiClient.shared().interface()?.powerOn() ?? false }
    static func setWifi(_ on: Bool) { try? CWWiFiClient.shared().interface()?.setPower(on) }
    static func bluetooth() -> Bool { btGet() != 0 }
    static func setBluetooth(_ on: Bool) { btSet(on ? 1 : 0) }
    static func dark() -> Bool { UserDefaults.standard.string(forKey: "AppleInterfaceStyle") == "Dark" }
    static func setDark(_ on: Bool) {
        _ = NowPlaying.run("tell application \"System Events\" to tell appearance preferences to set dark mode to \(on)")
    }
}

