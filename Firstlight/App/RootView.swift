import FoldPosture
import SwiftData
import SwiftUI

struct RootView: View {
    @Environment(AppModel.self) private var model
    @Environment(\.modelContext) private var context
    @Environment(\.scenePhase) private var scenePhase
    @AppStorage("hasCompletedOnboarding") private var hasCompletedOnboarding = false
    @AppStorage("simulatesHalfFold") private var simulatesHalfFold = false

    @State private var settings: AlarmSettings?
    @State private var showsBedtimeCheck = false

    var body: some View {
        ZStack {
            Palette.night.ignoresSafeArea()
            if let settings {
                content(settings)
            }
        }
        .task {
            settings = AlarmSettings.current(in: context)
            model.posture.simulatesHalfFold = simulatesHalfFold
            #if DEBUG
            applyDebugLaunch()
            #endif
            if let settings, hasCompletedOnboarding { model.resumeNightIfNeeded(with: settings) }
            await model.start()
            if let settings { await model.syncBackups(for: settings) }
        }
        .onChange(of: scenePhase) { _, phase in
            guard phase == .active, let settings else { return }
            model.power.refresh()
            model.backup.refreshAuthorization()
            Task { await model.syncBackups(for: settings) }
        }
    }

    @ViewBuilder
    private func content(_ settings: AlarmSettings) -> some View {
        @Bindable var model = model
        if hasCompletedOnboarding {
            HomeView(
                settings: settings,
                onBeginNight: { showsBedtimeCheck = true },
                onTest: { model.beginTest(with: settings) }
            )
            .transition(.opacity)
            .sheet(isPresented: $showsBedtimeCheck) {
                BedtimeCheckView(settings: settings) {
                    Task {
                        // Let the sheet finish dismissing before the night covers the screen.
                        try? await Task.sleep(for: .milliseconds(450))
                        await model.beginNight(with: settings)
                    }
                }
            }
            .fullScreenCover(item: $model.session) { session in
                NightView(session: session) {
                    model.finishSession(settings: settings)
                }
                .environment(model.power)
            }
            .onChange(of: settings.isArmed) { syncBackups(settings) }
            .onChange(of: settings.schedule) { syncBackups(settings) }
            .onChange(of: settings.snoozeMinutes) { syncBackups(settings) }
            .onChange(of: settings.sunriseMinutes) { syncBackups(settings) }
        } else {
            OnboardingView {
                withAnimation(.easeInOut(duration: 0.8)) { hasCompletedOnboarding = true }
            }
            .transition(.opacity)
        }
    }

    #if DEBUG
    private func applyDebugLaunch() {
        guard let screen = DebugLaunch.screen else { return }
        hasCompletedOnboarding = screen != "onboarding"
        if DebugLaunch.simulatesFold { model.posture.simulatesHalfFold = true }
        DebugLaunch.rotateIfRequested()
        if DebugLaunch.isTakingScreenshots { settings?.isArmed = true }
        DebugLaunch.setScreenshotClock(sunriseDuration: settings?.sunriseDuration ?? 1800)
        if screen == "bedtime" { showsBedtimeCheck = true }
        if let settings, let session = DebugLaunch.session(settings: settings, isPro: model.isPro) {
            model.session = session
        }
    }
    #endif

    /// The user changed the alarm, so any one-off target is re-chosen from the new settings.
    private func syncBackups(_ settings: AlarmSettings) {
        settings.oneOffWake = nil
        try? context.save()
        Task { await model.syncBackups(for: settings) }
    }
}
