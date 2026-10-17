import AVFoundation
import Observation
import UIKit

/// Battery, Low Power Mode, heat and volume: everything that can quietly ruin a sunrise.
@MainActor
@Observable
final class PowerMonitor {
    private(set) var batteryState: UIDevice.BatteryState = .unknown
    private(set) var batteryLevel: Float = -1
    private(set) var isLowPowerMode = false
    private(set) var thermalState: ProcessInfo.ThermalState = .nominal
    private(set) var outputVolume: Float = 1
    /// The alarm would play into earbuds or a speaker that may be off or out of the room.
    private(set) var isOnExternalAudio = false

    @ObservationIgnored private var observers: [NSObjectProtocol] = []
    @ObservationIgnored private var volumeObservation: NSKeyValueObservation?

    /// Nil when iOS won't say (the simulator, for one).
    var isCharging: Bool? {
        switch batteryState {
        case .charging, .full: true
        case .unplugged: false
        case .unknown: nil
        @unknown default: nil
        }
    }

    var isHot: Bool {
        thermalState == .serious || thermalState == .critical
    }

    func start() {
        guard observers.isEmpty else { return }
        UIDevice.current.isBatteryMonitoringEnabled = true
        refresh()

        let center = NotificationCenter.default
        let names: [Notification.Name] = [
            UIDevice.batteryStateDidChangeNotification,
            UIDevice.batteryLevelDidChangeNotification,
            .NSProcessInfoPowerStateDidChange,
            ProcessInfo.thermalStateDidChangeNotification,
            AVAudioSession.routeChangeNotification,
        ]
        observers = names.map { name in
            center.addObserver(forName: name, object: nil, queue: .main) { [weak self] _ in
                MainActor.assumeIsolated { self?.refresh() }
            }
        }

        let session = AVAudioSession.sharedInstance()
        outputVolume = session.outputVolume
        volumeObservation = session.observe(\.outputVolume, options: [.new]) { [weak self] _, change in
            guard let volume = change.newValue else { return }
            Task { @MainActor in self?.outputVolume = volume }
        }
    }

    func refresh() {
        let device = UIDevice.current
        batteryState = device.batteryState
        batteryLevel = device.batteryLevel
        isLowPowerMode = ProcessInfo.processInfo.isLowPowerModeEnabled
        thermalState = ProcessInfo.processInfo.thermalState
        let session = AVAudioSession.sharedInstance()
        outputVolume = session.outputVolume
        let external: Set<AVAudioSession.Port> = [.headphones, .bluetoothA2DP, .bluetoothHFP, .bluetoothLE, .airPlay, .carAudio]
        isOnExternalAudio = session.currentRoute.outputs.contains { external.contains($0.portType) }
    }
}

extension ProcessInfo.ThermalState {
    var label: String {
        switch self {
        case .nominal: "Cool"
        case .fair: "Warm"
        case .serious: "Hot"
        case .critical: "Too hot"
        @unknown default: "Unknown"
        }
    }

    /// 0 = nominal … 3 = critical, for charts.
    var level: Int {
        switch self {
        case .nominal: 0
        case .fair: 1
        case .serious: 2
        case .critical: 3
        @unknown default: 0
        }
    }
}
