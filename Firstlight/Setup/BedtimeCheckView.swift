import FoldPosture
import SwiftUI

/// The last screen before lights out: live checks for power, posture and the backup alarm.
struct BedtimeCheckView: View {
    let settings: AlarmSettings
    var onGoodNight: () -> Void

    @Environment(AppModel.self) private var model
    @Environment(\.dismiss) private var dismiss

    private enum Status {
        case good, warn, unknown

        var symbol: String {
            switch self {
            case .good: "checkmark.circle.fill"
            case .warn: "exclamationmark.circle.fill"
            case .unknown: "questionmark.circle"
            }
        }

        var color: Color {
            switch self {
            case .good: Color(red: 0.55, green: 0.85, blue: 0.6)
            case .warn: Palette.amber
            case .unknown: Palette.inkTertiary
            }
        }
    }

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 24) {
                SheetHeader(title: "Before you sleep")

                PlacementGuideView(foldable: model.posture.isFoldable, style: settings.curve(isPro: model.isPro).style)
                    .frame(height: 170)
                    .padding(.vertical, 4)

                VStack(spacing: 0) {
                    row(chargingStatus, "Power", chargingDetail)
                    divider
                    row(postureStatus, "Position", postureDetail)
                    divider
                    row(model.power.isLowPowerMode ? .warn : .good, "Low Power Mode",
                        model.power.isLowPowerMode ? "On. It can hold the screen dimmer than the sunrise needs." : "Off")
                    divider
                    row(model.power.outputVolume < 0.3 ? .warn : .good, "Volume",
                        "\(Int((model.power.outputVolume * 100).rounded()))%" + (model.power.outputVolume < 0.3 ? ". Turn it up so the alarm can wake you." : ""))
                    divider
                    backupRow
                }
                .glassPanel(cornerRadius: 26, padding: 6)

                VStack(alignment: .leading, spacing: 10) {
                    Eyebrow("Reminders")
                    reminder("Leave Firstlight open. Locking the phone stops the sunrise, though the backup alarm still rings.")
                    if settings.torchEnabled {
                        reminder(model.posture.isFoldable
                            ? "Flashlight boost is on: camera half on top, facing a light wall"
                            : "Flashlight boost is on: a light wall close behind the phone helps")
                    }
                    reminder("Night Shift and True Tone off for the night")
                    reminder("Sleep Focus on")
                }

                Button {
                    dismiss()
                    onGoodNight()
                } label: {
                    Label("Good night", systemImage: "moon.zzz.fill")
                }
                .buttonStyle(.glow)
            }
            .padding(24)
        }
        .scrollIndicators(.hidden)
        .presentationDetents([.large])
        .nightSheetStyle()
        .onAppear { model.power.refresh() }
    }

    private var divider: some View {
        Rectangle().fill(Palette.hairline).frame(height: 1).padding(.leading, 52)
    }

    private func row(_ status: Status, _ title: String, _ detail: String) -> some View {
        HStack(alignment: .top, spacing: 14) {
            Image(systemName: status.symbol)
                .scaledFont(20, design: .default)
                .foregroundStyle(status.color)
                .frame(width: 26)
                .contentTransition(.symbolEffect(.replace))
            VStack(alignment: .leading, spacing: 3) {
                Text(title)
                    .scaledFont(16, weight: .medium, design: .rounded)
                    .foregroundStyle(Palette.ink)
                Text(detail)
                    .scaledFont(13, design: .rounded)
                    .foregroundStyle(Palette.inkSecondary)
                    .fixedSize(horizontal: false, vertical: true)
            }
            Spacer(minLength: 0)
        }
        .padding(14)
        .accessibilityElement(children: .combine)
    }

    private var backupRow: some View {
        HStack(alignment: .center, spacing: 14) {
            let authorized = model.backup.isAuthorized
            Image(systemName: authorized ? Status.good.symbol : Status.warn.symbol)
                .scaledFont(20, design: .default)
                .foregroundStyle(authorized ? Status.good.color : Status.warn.color)
                .frame(width: 26)
            VStack(alignment: .leading, spacing: 3) {
                Text("Backup alarm")
                    .scaledFont(16, weight: .medium, design: .rounded)
                    .foregroundStyle(Palette.ink)
                Text(authorized
                    ? "Rings at \(TimeText.short(backupTime)) if Firstlight is closed"
                    : "Not allowed. Without it, closing the app means no alarm.")
                    .scaledFont(13, design: .rounded)
                    .foregroundStyle(Palette.inkSecondary)
            }
            Spacer(minLength: 0)
            if !authorized {
                Button("Allow") {
                    Task {
                        if model.backup.canAskForAuthorization {
                            await model.backup.requestAuthorization()
                        } else if let url = URL(string: UIApplication.openSettingsURLString) {
                            await UIApplication.shared.open(url)
                        }
                    }
                }
                .buttonStyle(GlassCapsuleButtonStyle(tint: Palette.amber))
            }
        }
        .padding(14)
    }

    private var backupTime: Date {
        (settings.schedule.nextWake(after: .now) ?? .now).addingTimeInterval(BackupAlarmService.delay)
    }

    private func reminder(_ text: String) -> some View {
        HStack(spacing: 10) {
            Circle().fill(Palette.amber.opacity(0.7)).frame(width: 5, height: 5)
            Text(text)
                .scaledFont(14, design: .rounded)
                .foregroundStyle(Palette.inkSecondary)
        }
    }

    // MARK: Status

    private var chargingStatus: Status {
        switch model.power.isCharging {
        case true?: .good
        case false?: .warn
        case nil: .unknown
        }
    }

    private var chargingDetail: String {
        switch model.power.isCharging {
        case true?: "Plugged in"
        case false?: "Not charging. A full-brightness sunrise can drain the battery overnight."
        case nil: "Can't tell. Make sure it's plugged in."
        }
    }

    private var postureStatus: Status {
        switch model.posture.posture {
        case .halfFolded, .standing: .good
        case .flat, .faceDown, .closed: .warn
        case .unknown: .unknown
        }
    }

    private var postureDetail: String {
        let foldable = model.posture.isFoldable
        switch model.posture.posture {
        case .halfFolded: return "Half-folded. Point the top half at your pillow."
        case .standing: return foldable ? "Open flat. Fold it halfway so the top half faces you." : "Standing up, facing you"
        case .flat: return foldable ? "Lying flat. Fold it halfway like a tent." : "Lying flat, so it lights the ceiling. Prop it on a stand."
        case .faceDown: return "Face down. Turn the screen toward the pillow."
        case .closed: return "Closed. Open it halfway."
        case .unknown: return foldable ? "Fold it halfway, top half toward the pillow." : "Prop it up so the screen faces your pillow."
        }
    }
}
