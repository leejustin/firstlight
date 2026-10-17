import AVFoundation

/// Two looping layers: a nature bed that fades in before wake time, and the alarm tune on top.
/// Volumes are set every tick from the session's clock rather than with long fades, so joining a
/// night halfway through sounds the same as being there from the start.
@MainActor
final class SoundEngine {
    private var nature: AVAudioPlayer?
    private var natureName: String?
    private var alarm: AVAudioPlayer?
    private var preview: AVAudioPlayer?

    static let alarmFileName = "morning"

    private func activateSession() {
        let session = AVAudioSession.sharedInstance()
        // .playback ignores the silent switch, which an alarm must.
        try? session.setCategory(.playback, mode: .default, options: [])
        try? session.setActive(true)
    }

    private func makePlayer(named name: String) -> AVAudioPlayer? {
        guard let url = Bundle.main.url(forResource: name, withExtension: "caf") else { return nil }
        let player = try? AVAudioPlayer(contentsOf: url)
        player?.numberOfLoops = -1
        player?.volume = 0
        player?.prepareToPlay()
        return player
    }

    /// Nature layer volume, 0...1. Starts playback the first time it rises above zero.
    func setNature(_ sound: NatureSound, volume: Double) {
        guard let name = sound.fileName else {
            nature?.stop()
            nature = nil
            return
        }
        if natureName != name {
            nature?.stop()
            nature = makePlayer(named: name)
            natureName = name
        }
        guard let nature else { return }
        if volume > 0.001 && !nature.isPlaying {
            activateSession()
            nature.play()
        }
        nature.volume = Float(min(max(volume, 0), 1))
    }

    func setAlarm(volume: Double) {
        if alarm == nil { alarm = makePlayer(named: Self.alarmFileName) }
        guard let alarm else { return }
        if volume > 0.001 && !alarm.isPlaying {
            activateSession()
            alarm.currentTime = 0
            alarm.play()
        }
        alarm.volume = Float(min(max(volume, 0), 1))
    }

    func stopAlarm() {
        alarm?.setVolume(0, fadeDuration: 0.6)
        let player = alarm
        Task {
            try? await Task.sleep(for: .milliseconds(700))
            player?.stop()
        }
    }

    /// Plays a few seconds of a sound in settings.
    func playPreview(_ sound: NatureSound) {
        preview?.stop()
        guard let name = sound.fileName, let player = makePlayer(named: name) else { return }
        activateSession()
        player.numberOfLoops = 0
        player.volume = 0
        player.play()
        player.setVolume(0.8, fadeDuration: 0.8)
        preview = player
        Task { [weak self] in
            try? await Task.sleep(for: .seconds(6))
            guard self?.preview === player else { return }
            player.setVolume(0, fadeDuration: 1.2)
            try? await Task.sleep(for: .seconds(1.3))
            player.stop()
        }
    }

    func stopPreview() {
        preview?.stop()
        preview = nil
    }

    func stopAll(fade: TimeInterval = 2) {
        let players = [nature, alarm].compactMap { $0 }
        for player in players { player.setVolume(0, fadeDuration: fade) }
        nature = nil
        natureName = nil
        alarm = nil
        Task {
            try? await Task.sleep(for: .seconds(fade + 0.1))
            players.forEach { $0.stop() }
            try? AVAudioSession.sharedInstance().setActive(false, options: .notifyOthersOnDeactivation)
        }
    }
}
