import WidgetKit
import SwiftUI

struct Entry: TimelineEntry { let date: Date; let s: DeckState }

struct Provider: TimelineProvider {
    func placeholder(in context: Context) -> Entry { Entry(date: .now, s: DeckState()) }
    func getSnapshot(in context: Context, completion: @escaping (Entry) -> Void) {
        completion(Entry(date: .now, s: .load()))
    }
    func getTimeline(in context: Context, completion: @escaping (Timeline<Entry>) -> Void) {
        completion(Timeline(entries: [Entry(date: .now, s: .load())], policy: .after(.now.addingTimeInterval(900))))
    }
}

func deck(_ a: String) -> URL { URL(string: "controldeck://\(a)")! }

struct DeckView: View {
    @Environment(\.widgetFamily) var family
    let s: DeckState

    var body: some View {
        VStack(spacing: 10) {
            HStack(spacing: 8) {
                toggle("wifi", s.wifi ? "wifi" : "wifi.slash", "Wi-Fi", s.wifi)
                toggle("bluetooth", "dot.radiowaves.left.and.right", "Bluetooth", s.bluetooth)
                toggle("dark", "circle.lefthalf.filled", "Dark Mode", s.dark)
            }
            if family == .systemLarge {
                level("sun.max.fill", s.brightness, "brightdown", "brightup")
                level(s.volume == 0 ? "speaker.slash.fill" : "speaker.wave.2.fill", s.volume, "voldown", "volup")
            }
            player
        }
    }

    func toggle(_ a: String, _ icon: String, _ title: String, _ on: Bool) -> some View {
        Link(destination: deck(a)) {
            VStack(spacing: 4) {
                Image(systemName: icon).font(.system(size: 15, weight: .semibold))
                    .foregroundStyle(on ? Color.white : Color.primary)
                    .frame(width: 34, height: 34)
                    .background(on ? Color.accentColor : Color.secondary.opacity(0.25), in: Circle())
                Text(title).font(.system(size: 11, weight: .medium))
            }
            .frame(maxWidth: .infinity)
        }
    }

    func level(_ icon: String, _ v: Double, _ down: String, _ up: String) -> some View {
        HStack(spacing: 8) {
            Link(destination: deck(down)) {
                Image(systemName: "minus").font(.system(size: 11, weight: .bold))
                    .frame(width: 26, height: 26).background(.quaternary, in: Circle())
            }
            GeometryReader { g in
                ZStack(alignment: .leading) {
                    Capsule().fill(.quaternary)
                    Capsule().fill(Color.white.opacity(0.95)).frame(width: max(28, g.size.width * v))
                    Image(systemName: icon).font(.system(size: 12, weight: .semibold))
                        .foregroundStyle(Color.black.opacity(0.55)).padding(.leading, 9)
                }
            }
            .frame(height: 28)
            Link(destination: deck(up)) {
                Image(systemName: "plus").font(.system(size: 11, weight: .bold))
                    .frame(width: 26, height: 26).background(.quaternary, in: Circle())
            }
        }
    }

    var player: some View {
        HStack(spacing: 10) {
            Group {
                if let d = s.art, let img = NSImage(data: d) { Image(nsImage: img).resizable().scaledToFill() }
                else { Image(systemName: "music.note").foregroundStyle(.secondary) }
            }
            .frame(width: 48, height: 48).background(.quaternary)
            .clipShape(RoundedRectangle(cornerRadius: 9, style: .continuous))
            if let t = s.title {
                VStack(alignment: .leading, spacing: 2) {
                    Text(t).font(.system(size: 12, weight: .semibold)).lineLimit(1)
                    Text(s.artist ?? "").font(.system(size: 11)).foregroundStyle(.secondary).lineLimit(1)
                }
                Spacer(minLength: 4)
                HStack(spacing: 14) {
                    Link(destination: deck("prev")) { Image(systemName: "backward.fill") }
                    Link(destination: deck("play")) { Image(systemName: s.playing ? "pause.fill" : "play.fill").font(.system(size: 18)) }
                    Link(destination: deck("next")) { Image(systemName: "forward.fill") }
                }
                .font(.system(size: 13))
            } else {
                Text("Nothing playing").font(.system(size: 12)).foregroundStyle(.secondary)
                Spacer()
            }
        }
        .padding(8)
        .background(.quaternary.opacity(0.5), in: RoundedRectangle(cornerRadius: 14, style: .continuous))
    }
}

@main
struct ControlDeckWidget: Widget {
    var body: some WidgetConfiguration {
        StaticConfiguration(kind: "ControlDeck", provider: Provider()) { e in
            DeckView(s: e.s).containerBackground(.fill.tertiary, for: .widget)
        }
        .configurationDisplayName("ControlDeck")
        .description("Wi-Fi, Bluetooth, Dark Mode, brightness, volume and Now Playing.")
        .supportedFamilies([.systemMedium, .systemLarge])
    }
}
