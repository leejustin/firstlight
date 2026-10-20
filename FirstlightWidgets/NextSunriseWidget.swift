import SwiftUI
import WidgetKit

struct SunriseEntry: TimelineEntry {
    let date: Date
    let snapshot: WidgetSnapshot?
}

struct SunriseProvider: TimelineProvider {
    func placeholder(in context: Context) -> SunriseEntry {
        SunriseEntry(date: .now, snapshot: WidgetSnapshot(isArmed: true, nextWake: .now.addingTimeInterval(8 * 3600), sunriseMinutes: 30))
    }

    func getSnapshot(in context: Context, completion: @escaping (SunriseEntry) -> Void) {
        completion(context.isPreview ? placeholder(in: context) : SunriseEntry(date: .now, snapshot: WidgetSnapshot.load()))
    }

    func getTimeline(in context: Context, completion: @escaping (Timeline<SunriseEntry>) -> Void) {
        let snapshot = WidgetSnapshot.load()
        let entry = SunriseEntry(date: .now, snapshot: snapshot)
        // The app reloads timelines whenever the alarm changes; this just rolls past wake time.
        let refresh = snapshot?.nextWake.map { $0.addingTimeInterval(60) } ?? .now.addingTimeInterval(6 * 3600)
        completion(Timeline(entries: [entry], policy: .after(max(refresh, .now.addingTimeInterval(15 * 60)))))
    }
}

struct NextSunriseWidget: Widget {
    var body: some WidgetConfiguration {
        StaticConfiguration(kind: "NextSunrise", provider: SunriseProvider()) { entry in
            NextSunriseView(entry: entry)
        }
        .configurationDisplayName("Next sunrise")
        .description("When the light starts and when the alarm rings.")
        .supportedFamilies([.accessoryRectangular, .accessoryInline, .systemSmall])
    }
}

struct NextSunriseView: View {
    let entry: SunriseEntry

    @Environment(\.widgetFamily) private var family

    private var wake: Date? {
        guard let snapshot = entry.snapshot, snapshot.isArmed, let wake = snapshot.nextWake, wake > entry.date else { return nil }
        return wake
    }

    var body: some View {
        switch family {
        case .accessoryInline:
            if let wake, let start = entry.snapshot?.sunriseStart {
                Label("Light \(start.formatted(date: .omitted, time: .shortened)), alarm \(wake.formatted(date: .omitted, time: .shortened))", systemImage: "sun.horizon")
            } else {
                Label("No alarm", systemImage: "sun.horizon")
            }
        case .accessoryRectangular:
            rectangular
                .containerBackground(.clear, for: .widget)
        default:
            small
                .containerBackground(for: .widget) { background }
        }
    }

    private var rectangular: some View {
        HStack(spacing: 8) {
            Image(systemName: "sun.horizon.fill")
                .font(.title3)
            VStack(alignment: .leading, spacing: 1) {
                if let wake, let start = entry.snapshot?.sunriseStart {
                    Text(wake, style: .time)
                        .font(.headline)
                    Text("Light from \(start.formatted(date: .omitted, time: .shortened))")
                        .font(.caption)
                } else {
                    Text("Firstlight")
                        .font(.headline)
                    Text("No alarm set")
                        .font(.caption)
                }
            }
            Spacer(minLength: 0)
        }
        .widgetAccentable()
    }

    private var small: some View {
        VStack(alignment: .leading, spacing: 4) {
            Image(systemName: "sun.horizon.fill")
                .foregroundStyle(WidgetPalette.amber)
            Spacer()
            if let wake, let start = entry.snapshot?.sunriseStart {
                Text(wake, style: .time)
                    .font(.system(size: 30, weight: .light, design: .rounded))
                    .foregroundStyle(WidgetPalette.ink)
                    .minimumScaleFactor(0.7)
                Text("Light from \(start.formatted(date: .omitted, time: .shortened))")
                    .font(.system(size: 13, design: .rounded))
                    .foregroundStyle(WidgetPalette.ink.opacity(0.65))
            } else {
                Text("No alarm set")
                    .font(.system(size: 17, weight: .medium, design: .rounded))
                    .foregroundStyle(WidgetPalette.ink)
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .leading)
    }

    private var background: some View {
        ZStack {
            WidgetPalette.night
            RadialGradient(
                colors: [WidgetPalette.ember.opacity(0.55), WidgetPalette.crimson.opacity(0.35), .clear],
                center: .bottom,
                startRadius: 0,
                endRadius: 140
            )
        }
    }
}
