import Charts
import SwiftUI

/// Answers the spec's open question on real hardware: will iOS hold full brightness for 30
/// minutes, or dim for heat? Holds full white, samples what iOS reports, and lets you note the
/// lux your meter reads at the pillow.
struct LightCheckView: View {
    @Environment(AppModel.self) private var model
    @State private var minutes = 30
    @State private var hdrBoost = true
    @State private var run: LightCheckRun?
    @AppStorage("lightCheckLux") private var luxNote = ""

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 24) {
                Text("Holds the screen at full white and brightness, logging every 5 seconds what brightness iOS actually reports, plus heat and battery. Put a light meter where your eyes would be.")
                    .scaledFont(15, design: .rounded)
                    .foregroundStyle(Palette.inkSecondary)

                Picker("Length", selection: $minutes) {
                    ForEach([5, 15, 30, 45], id: \.self) { Text("\($0) min").tag($0) }
                }
                .pickerStyle(.segmented)

                Toggle("HDR boost, as at the end of a sunrise", isOn: $hdrBoost)
                    .scaledFont(15, weight: .medium, design: .rounded)
                    .tint(Palette.ember)

                Button {
                    run = LightCheckRun(duration: TimeInterval(minutes * 60), hdrBoost: hdrBoost)
                } label: {
                    Label("Start light check", systemImage: "light.max")
                }
                .buttonStyle(.glow)

                VStack(alignment: .leading, spacing: 8) {
                    Eyebrow("Pillow lux (from your meter)")
                    TextField("e.g. 55", text: $luxNote)
                        .keyboardType(.numberPad)
                        .font(.system(size: 22, weight: .light, design: .rounded))
                        .padding(14)
                        .glassEffect(.regular, in: .rect(cornerRadius: 18))
                    Text("A dedicated wake-up lamp gives about 250–300 lux. The estimate for a phone is 30–70.")
                        .scaledFont(13, design: .rounded)
                        .foregroundStyle(Palette.inkTertiary)
                }

                if let last = LightCheckRun.lastSummary {
                    VStack(alignment: .leading, spacing: 6) {
                        Eyebrow("Last run")
                        Text(last)
                            .scaledFont(15, design: .rounded)
                            .foregroundStyle(Palette.ink)
                    }
                }
            }
            .padding(24)
        }
        .background(Palette.night)
        .navigationTitle("Light check")
        .fullScreenCover(item: $run) { run in
            LightCheckRunView(run: run) { self.run = nil }
        }
    }
}

@MainActor
@Observable
final class LightCheckRun: Identifiable {
    struct Sample: Identifiable {
        let elapsed: TimeInterval
        let brightness: Double
        let thermal: Int
        let battery: Double
        var id: TimeInterval { elapsed }
    }

    let id = UUID()
    let duration: TimeInterval
    let hdrBoost: Bool
    let start = Date.now
    private(set) var samples: [Sample] = []
    private(set) var isFinished = false

    @ObservationIgnored private let screen = ScreenController()
    @ObservationIgnored private var task: Task<Void, Never>?

    init(duration: TimeInterval, hdrBoost: Bool) {
        self.duration = duration
        self.hdrBoost = hdrBoost
    }

    func begin(power: PowerMonitor) {
        screen.begin()
        task = Task { [weak self] in
            while let self, !Task.isCancelled {
                self.screen.setBrightness(1, force: true)
                try? await Task.sleep(for: .milliseconds(300))
                power.refresh()
                let elapsed = Date.now.timeIntervalSince(self.start)
                self.samples.append(Sample(
                    elapsed: elapsed,
                    brightness: self.screen.reportedBrightness,
                    thermal: power.thermalState.level,
                    battery: Double(max(power.batteryLevel, 0))
                ))
                if elapsed >= self.duration {
                    self.finish()
                    return
                }
                try? await Task.sleep(for: .seconds(4.7))
            }
        }
    }

    func finish() {
        guard !isFinished else { return }
        isFinished = true
        task?.cancel()
        screen.end()
        Self.lastSummary = summary
    }

    var summary: String {
        guard let last = samples.last else { return "No samples" }
        let low = samples.map(\.brightness).min() ?? 0
        let hottest = samples.map(\.thermal).max() ?? 0
        let thermal = ["cool", "warm", "hot", "too hot"][min(hottest, 3)]
        let held = Duration.seconds(last.elapsed).formatted(.time(pattern: .minuteSecond))
        return "Held \(held)\(hdrBoost ? " with HDR" : ""). Lowest brightness \(Int(low * 100))%, peak heat \(thermal)."
    }

    static var lastSummary: String? {
        get { UserDefaults.standard.string(forKey: "lightCheckSummary") }
        set { UserDefaults.standard.set(newValue, forKey: "lightCheckSummary") }
    }
}

private struct LightCheckRunView: View {
    let run: LightCheckRun
    var onClose: () -> Void

    @Environment(AppModel.self) private var model
    @Environment(\.scenePhase) private var scenePhase
    @State private var showsReadout = true

    var body: some View {
        ZStack(alignment: .bottom) {
            Color.white
                .exposureAdjust(run.hdrBoost ? SunriseCurve.maxBoostStops : 0)
                .allowedDynamicRange(.high)

            if showsReadout || run.isFinished {
                readout
                    .padding(20)
                    .transition(.move(edge: .bottom).combined(with: .opacity))
            }
        }
        .immersive()
        .onTapGesture { withAnimation { showsReadout.toggle() } }
        .onAppear { run.begin(power: model.power) }
        .onDisappear { run.finish() }
        .onChange(of: scenePhase) { _, phase in
            // Leaving the app ends the run, so it can't leave the phone stuck at full brightness.
            if phase == .background { run.finish() }
        }
    }

    private var readout: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                Eyebrow(run.isFinished ? "Finished" : "Running", color: Palette.daylightInk.opacity(0.6))
                Spacer()
                Text(run.summary)
                    .scaledFont(12, weight: .medium, design: .rounded)
                    .foregroundStyle(Palette.daylightInk.opacity(0.7))
            }
            Chart(run.samples) { sample in
                LineMark(x: .value("Minutes", sample.elapsed / 60), y: .value("Brightness", sample.brightness))
                    .foregroundStyle(Palette.ember)
                LineMark(x: .value("Minutes", sample.elapsed / 60), y: .value("Heat", Double(sample.thermal) / 3))
                    .foregroundStyle(Palette.daylightInk.opacity(0.4))
                    .lineStyle(StrokeStyle(lineWidth: 1, dash: [3, 3]))
            }
            .chartYScale(domain: 0...1)
            .chartXScale(domain: 0...max(run.duration / 60, 1))
            .frame(height: 110)
            Text("Orange: brightness iOS reports. Dashed: heat. Tap the screen to hide this panel while measuring.")
                .scaledFont(11, design: .rounded)
                .foregroundStyle(Palette.daylightInk.opacity(0.55))
            Button(run.isFinished ? "Close" : "Stop", action: onClose)
                .buttonStyle(.daylight)
        }
        .padding(18)
        .background(.white.opacity(0.75), in: .rect(cornerRadius: 26))
        .overlay(RoundedRectangle(cornerRadius: 26).strokeBorder(Palette.daylightInk.opacity(0.1)))
    }
}
