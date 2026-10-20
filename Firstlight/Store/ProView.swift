import SwiftUI

struct ProView: View {
    @Environment(AppModel.self) private var model
    @Environment(\.dismiss) private var dismiss

    private let showcase: [SunriseStyle] = [.coastal, .ember, .nordic, .dawn]

    var body: some View {
        ScrollView {
            VStack(spacing: 28) {
                TimelineView(.periodic(from: .now, by: 3.5)) { context in
                    let index = Int(context.date.timeIntervalSinceReferenceDate / 3.5) % showcase.count
                    ZStack {
                        HorizonGlow(style: showcase[index], intensity: 0.8)
                            .frame(width: 420, height: 260)
                            .offset(y: 90)
                        HorizonMark(style: showcase[index])
                            .frame(width: 150, height: 150)
                    }
                    .frame(height: 190)
                    .animation(.easeInOut(duration: 1.6), value: index)
                }

                VStack(spacing: 10) {
                    Text("Firstlight Pro")
                        .font(.display(34))
                        .multilineTextAlignment(.center)
                        .foregroundStyle(Palette.ink)
                    Text("One purchase, no subscription.")
                        .scaledFont(15, design: .rounded)
                        .foregroundStyle(Palette.inkSecondary)
                }

                VStack(alignment: .leading, spacing: 18) {
                    feature("paintpalette", "More sunrise styles", "Ember, Coastal and Nordic, plus a custom ending color.")
                    feature("chart.line.uptrend.xyaxis", "Custom curves", "Two more ways for the brightness to rise.")
                    feature("music.note", "All sounds", "Soft rain and wind chimes alongside birdsong.")
                    feature("moon.haze", "Wind-down sunset", "A dim orange glow at bedtime that fades out over 5–20 minutes.")
                    feature("lightbulb.2", "HomeKit lamps", "Your lamps follow the sunrise too, from deep red to daylight, for much more light than a screen.")
                }
                .glassPanel(cornerRadius: 28, padding: 22)

                VStack(spacing: 12) {
                    if model.isPro {
                        Label("You have Pro", systemImage: "checkmark.seal.fill")
                            .scaledFont(17, weight: .semibold, design: .rounded)
                            .foregroundStyle(Palette.amber)
                            .frame(minHeight: 58)
                    } else {
                        Button {
                            Task { await model.store.purchase() }
                        } label: {
                            if model.store.purchaseState == .purchasing {
                                ProgressView().tint(Palette.night)
                            } else {
                                Text("Unlock for \(model.store.displayPrice)")
                            }
                        }
                        .buttonStyle(.glow)
                        .disabled(model.store.purchaseState == .purchasing)
                    }

                    if case .failed(let message) = model.store.purchaseState {
                        Text(message)
                            .font(.footnote)
                            .foregroundStyle(Palette.amber)
                    }
                    if model.store.purchaseState == .pending {
                        Text("Waiting for approval…")
                            .font(.footnote)
                            .foregroundStyle(Palette.inkSecondary)
                    }

                    Button("Restore purchase") {
                        Task { await model.store.restore() }
                    }
                    .scaledFont(14, weight: .medium, design: .rounded)
                    .foregroundStyle(Palette.inkSecondary)
                    .frame(minHeight: 44)
                }
            }
            .padding(24)
        }
        .scrollIndicators(.hidden)
        .presentationDetents([.large])
        .nightSheetStyle()
        .onChange(of: model.isPro) { _, isPro in
            if isPro { dismiss() }
        }
    }

    private func feature(_ symbol: String, _ title: String, _ detail: String) -> some View {
        HStack(alignment: .top, spacing: 16) {
            Image(systemName: symbol)
                .scaledFont(18, design: .default)
                .foregroundStyle(Palette.amber)
                .frame(width: 28)
            VStack(alignment: .leading, spacing: 3) {
                Text(title)
                    .scaledFont(16, weight: .semibold, design: .rounded)
                    .foregroundStyle(Palette.ink)
                Text(detail)
                    .scaledFont(14, design: .rounded)
                    .foregroundStyle(Palette.inkSecondary)
            }
        }
    }
}
