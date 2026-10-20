import FoldPosture
import SwiftUI

struct SettingsView: View {
    @Bindable var settings: AlarmSettings
    var showPro: () -> Void

    @Environment(AppModel.self) private var model
    @Environment(\.dismiss) private var dismiss
    @AppStorage("simulatesHalfFold") private var simulatesHalfFold = false
    @AppStorage("hasCompletedOnboarding") private var hasCompletedOnboarding = true

    var body: some View {
        NavigationStack {
            List {
                Section {
                    proRow
                }

                Section("Setup") {
                    NavigationLink {
                        PlacementPage(foldable: model.posture.isFoldable)
                    } label: {
                        label("Placement guide", "rectangle.portrait.and.arrow.right")
                    }
                    NavigationLink {
                        BedtimeTipsPage()
                    } label: {
                        label("Bedtime settings to change", "moon.circle")
                    }
                    Button {
                        dismiss()
                        hasCompletedOnboarding = false
                    } label: {
                        label("Replay welcome", "sparkles")
                    }
                }

                Section {
                    NavigationLink {
                        LightCheckView()
                    } label: {
                        label("Light check", "light.max")
                    }
                    Toggle(isOn: $simulatesHalfFold) {
                        label("Simulate half-fold", "rectangle.split.1x2")
                    }
                    .tint(Palette.ember)
                    LabeledContent("Hinge", value: hingeDescription)
                    LabeledContent("Posture", value: postureDescription)
                } header: {
                    Text("Diagnostics")
                } footer: {
                    Text("Light check holds full white and logs whether iOS keeps the brightness. Simulate half-fold puts the light on the top half, as on a folded Duo.")
                }

                Section("Backup alarm") {
                    LabeledContent("Permission") {
                        Text(model.backup.isAuthorized ? "Allowed" : "Not allowed")
                            .foregroundStyle(model.backup.isAuthorized ? Palette.inkSecondary : Palette.amber)
                    }
                    if !model.backup.isAuthorized, let url = URL(string: UIApplication.openSettingsURLString) {
                        Link("Open Settings", destination: url)
                            .foregroundStyle(Palette.amber)
                    }
                    if let error = model.backup.lastError {
                        Text(error)
                            .font(.footnote)
                            .foregroundStyle(Palette.inkTertiary)
                    }
                }

                Section {
                    LabeledContent("Version", value: Bundle.main.versionString)
                } footer: {
                    Text("Dawnfold keeps your alarm settings in iCloud. Nothing else leaves your phone.")
                }
            }
            .scrollContentBackground(.hidden)
            .background(Palette.nightRaised.opacity(0.4))
            .navigationTitle("Settings")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .confirmationAction) {
                    Button("Done") { dismiss() }
                }
            }
        }
        .tint(Palette.amber)
        .presentationDetents([.large])
        .nightSheetStyle()
        .onChange(of: simulatesHalfFold, initial: true) { _, value in
            model.posture.simulatesHalfFold = value
        }
    }

    /// What the hinge sensor says right now, for checking postures on a Duo or in DeviceHub.
    private var hingeDescription: String {
        guard let reading = model.posture.hingeReading else { return "None (not a foldable)" }
        let status = switch reading.status {
        case .closed: "Closed"
        case .partiallyOpen: "Partly open"
        case .fullyOpen: "Fully open"
        case .unknown: "Unknown"
        }
        return "\(status), \(Int((reading.angle * 180 / .pi).rounded()))°"
    }

    private var postureDescription: String {
        switch model.posture.posture {
        case .halfFolded: "Half-folded (light on top)"
        case .standing: "Standing"
        case .flat: "Flat"
        case .faceDown: "Face down"
        case .closed: "Closed"
        case .unknown: "Unknown"
        }
    }

    private var proRow: some View {
        Button {
            if !model.isPro { showPro() }
        } label: {
            HStack(spacing: 14) {
                HorizonMark(style: .coastal)
                    .frame(width: 44, height: 44)
                VStack(alignment: .leading, spacing: 2) {
                    Text(model.isPro ? "Dawnfold Pro" : "Unlock Dawnfold Pro")
                        .scaledFont(17, weight: .semibold, design: .rounded)
                        .foregroundStyle(Palette.ink)
                    Text(model.isPro ? "Pro is unlocked." : "More styles, sounds and wind-down for \(model.store.displayPrice)")
                        .scaledFont(13, design: .rounded)
                        .foregroundStyle(Palette.inkSecondary)
                }
                Spacer()
                if !model.isPro {
                    Image(systemName: "chevron.right")
                        .scaledFont(13, weight: .semibold, design: .default)
                        .foregroundStyle(Palette.inkTertiary)
                }
            }
        }
        .buttonStyle(.plain)
    }

    private func label(_ title: String, _ symbol: String) -> some View {
        Label {
            Text(title).foregroundStyle(Palette.ink)
        } icon: {
            Image(systemName: symbol).foregroundStyle(Palette.amber)
        }
    }
}

private struct PlacementPage: View {
    let foldable: Bool

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 24) {
                PlacementGuideView(foldable: foldable)
                    .frame(height: 240)
                Group {
                    step("1", foldable ? "Set it up like a laptop" : "Stand it up", foldable
                        ? "Turn it sideways and fold it halfway. The bottom half rests flat on the nightstand, and the top half stands up and lights up."
                        : "Use a stand or lean it against something so the screen faces you.")
                    step("2", "Aim at the pillow", "The light should land on your closed eyes, not the ceiling.")
                    step("3", "40–60 cm from your head", "Closer is brighter. Light falls off quickly with distance.")
                    step("4", "Plug it in", "Full brightness for half an hour uses real power.")
                }
                Text("Run a test sunrise from the home screen to check the light reaches you.")
                    .scaledFont(14, design: .rounded)
                    .foregroundStyle(Palette.inkSecondary)
            }
            .padding(24)
        }
        .background(SkyBackground(dawn: 0.2, showsStars: false))
        .navigationTitle("Placement")
    }

    private func step(_ number: String, _ title: String, _ detail: String) -> some View {
        HStack(alignment: .top, spacing: 16) {
            Text(number)
                .font(.display(22))
                .foregroundStyle(Palette.amber)
                .frame(width: 24)
            VStack(alignment: .leading, spacing: 4) {
                Text(title).scaledFont(17, weight: .medium, design: .rounded).foregroundStyle(Palette.ink)
                Text(detail).scaledFont(14, design: .rounded).foregroundStyle(Palette.inkSecondary)
            }
        }
    }
}

private struct BedtimeTipsPage: View {
    var body: some View {
        List {
            tip("Night Shift", "Turn it off for the night. It shifts the screen toward yellow, which mutes the daylight at the end of the sunrise.", "Control Center › long-press brightness")
            tip("True Tone", "Turn it off too. It matches the room's light, so in a dark bedroom it tints and dims the white.", "Control Center › long-press brightness")
            tip("Sleep Focus", "Turn it on so notifications don't light the screen overnight.", "Control Center › Focus")
            tip("Auto-Lock", "Leave it as it is. Dawnfold keeps the screen awake by itself while a night is running.", nil)
        }
        .scrollContentBackground(.hidden)
        .background(Palette.night)
        .navigationTitle("Bedtime settings")
    }

    private func tip(_ title: String, _ detail: String, _ path: String?) -> some View {
        VStack(alignment: .leading, spacing: 6) {
            Text(title).scaledFont(17, weight: .semibold, design: .rounded).foregroundStyle(Palette.ink)
            Text(detail).scaledFont(14, design: .rounded).foregroundStyle(Palette.inkSecondary)
            if let path {
                Text(path).scaledFont(12, weight: .medium, design: .rounded).foregroundStyle(Palette.amber)
            }
        }
        .padding(.vertical, 6)
    }
}

extension Bundle {
    var versionString: String {
        let version = infoDictionary?["CFBundleShortVersionString"] as? String ?? "1.0"
        let build = infoDictionary?["CFBundleVersion"] as? String ?? "1"
        return "\(version) (\(build))"
    }
}
