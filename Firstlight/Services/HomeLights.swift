import HomeKit
import Observation

/// HomeKit lamps that brighten along with the screen (Pro). The app is open all night, so it drives
/// the lamps directly; HomeKit only accepts writes from the foreground.
@MainActor
@Observable
final class HomeLights: NSObject {
    struct Lamp: Identifiable, Hashable {
        let id: String
        let name: String
        let room: String?
        let home: String
    }

    enum Access: Equatable {
        case notAsked
        case denied
        case allowed
    }

    private(set) var lamps: [Lamp] = []
    private(set) var access: Access = .notAsked
    private(set) var isLoading = false

    @ObservationIgnored private var manager: HMHomeManager?
    @ObservationIgnored private var lastSent: LampState?
    @ObservationIgnored private var lastSentAt = Date.distantPast
    @ObservationIgnored private var inFlight = false

    /// HomeKit rate-limits accessories; a write every few seconds is plenty for a sunrise.
    static let minimumInterval: TimeInterval = 5

    /// Creating the manager is what shows the Home permission prompt, so it waits until the user
    /// turns lamps on.
    func connect() {
        guard manager == nil else { return }
        isLoading = true
        let manager = HMHomeManager()
        manager.delegate = self
        self.manager = manager
    }

    private func refresh() {
        guard let manager else { return }
        let status = manager.authorizationStatus
        if status.contains(.authorized) {
            access = .allowed
        } else if status.contains(.determined) || status.contains(.restricted) {
            access = .denied
        }
        lamps = manager.homes.flatMap { home in
            home.accessories.flatMap { accessory in
                accessory.services
                    .filter { $0.serviceType == HMServiceTypeLightbulb }
                    .map { service in
                        Lamp(
                            id: service.uniqueIdentifier.uuidString,
                            name: service.name.isEmpty ? accessory.name : service.name,
                            room: accessory.room?.name,
                            home: home.name
                        )
                    }
            }
        }
        .sorted { ($0.home, $0.room ?? "", $0.name) < ($1.home, $1.room ?? "", $1.name) }
        isLoading = false
    }

    private func services(for ids: Set<String>) -> [HMService] {
        guard let manager, !ids.isEmpty else { return [] }
        return manager.homes
            .flatMap { $0.accessories.flatMap(\.services) }
            .filter { ids.contains($0.uniqueIdentifier.uuidString) }
    }

    // MARK: Driving the lamps

    /// Sends a state to the lamps, skipping writes that wouldn't be visible yet.
    func apply(_ state: LampState, to ids: Set<String>, now: Date = .now) {
        guard !inFlight, !ids.isEmpty else { return }
        if let lastSent {
            let changedPower = lastSent.isOn != state.isOn
            let bigStep = abs(lastSent.brightness - state.brightness) >= 4
            guard changedPower || bigStep || now.timeIntervalSince(lastSentAt) >= Self.minimumInterval else { return }
            guard lastSent != state else { return }
        }
        lastSent = state
        lastSentAt = now
        let targets = services(for: ids)
        guard !targets.isEmpty else { return }
        inFlight = true
        Task {
            for service in targets { await Self.write(state, to: service) }
            inFlight = false
        }
    }

    func turnOff(_ ids: Set<String>) {
        lastSent = nil
        for service in services(for: ids) {
            Task { await Self.write(.off, to: service) }
        }
    }

    /// A ten-second sunrise on the chosen lamps, then back to how they were.
    func preview(_ ids: Set<String>, curve: SunriseCurve) async {
        let targets = services(for: ids)
        var before: [(service: HMService, power: Bool?, brightness: Int?)] = []
        for service in targets {
            let power = (try? await Self.read(HMCharacteristicTypePowerState, of: service)) as? Bool
            let brightness = (try? await Self.read(HMCharacteristicTypeBrightness, of: service)) as? Int
            before.append((service, power, brightness))
        }

        let steps = 10
        for step in 1...steps {
            let state = curve.lampState(at: Double(step) / Double(steps))
            for service in targets { await Self.write(state, to: service) }
            try? await Task.sleep(for: .seconds(1))
        }
        try? await Task.sleep(for: .seconds(2))

        for (service, power, brightness) in before {
            if let brightness {
                try? await Self.characteristic(HMCharacteristicTypeBrightness, of: service)?.writeValue(brightness)
            }
            try? await Self.characteristic(HMCharacteristicTypePowerState, of: service)?.writeValue(power ?? false)
        }
    }

    // MARK: HomeKit plumbing

    private static func characteristic(_ type: String, of service: HMService) -> HMCharacteristic? {
        service.characteristics.first { $0.characteristicType == type }
    }

    private static func read(_ type: String, of service: HMService) async throws -> Any? {
        guard let characteristic = characteristic(type, of: service) else { return nil }
        try await characteristic.readValue()
        return characteristic.value
    }

    /// Writes one state. Color lamps get hue and saturation; white lamps get a color temperature
    /// clamped to what they support.
    private static func write(_ state: LampState, to service: HMService) async {
        try? await characteristic(HMCharacteristicTypePowerState, of: service)?.writeValue(state.isOn)
        guard state.isOn else { return }
        try? await characteristic(HMCharacteristicTypeBrightness, of: service)?.writeValue(state.brightness)

        let hue = characteristic(HMCharacteristicTypeHue, of: service)
        let saturation = characteristic(HMCharacteristicTypeSaturation, of: service)
        let temperature = characteristic(HMCharacteristicTypeColorTemperature, of: service)

        if let temperature, state.prefersWhite || hue == nil {
            let low = temperature.metadata?.minimumValue?.intValue ?? 140
            let high = temperature.metadata?.maximumValue?.intValue ?? 500
            try? await temperature.writeValue(min(max(state.mireds, low), high))
        } else if let hue, let saturation {
            try? await hue.writeValue(state.hue)
            try? await saturation.writeValue(state.saturation)
        }
    }
}

extension HomeLights: HMHomeManagerDelegate {
    nonisolated func homeManagerDidUpdateHomes(_ manager: HMHomeManager) {
        MainActor.assumeIsolated { refresh() }
    }

    nonisolated func homeManager(_ manager: HMHomeManager, didUpdate status: HMHomeManagerAuthorizationStatus) {
        MainActor.assumeIsolated { refresh() }
    }
}
