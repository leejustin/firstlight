import FoldPosture
import SwiftData
import SwiftUI

@main
struct FirstlightApp: App {
    @State private var model = AppModel()

    private let container: ModelContainer = {
        let schema = Schema([AlarmSettings.self])
        // .automatic syncs through the iCloud container in the entitlements when the app is
        // signed for it, and stays local otherwise.
        let configuration = ModelConfiguration(schema: schema, cloudKitDatabase: .automatic)
        if let container = try? ModelContainer(for: schema, configurations: configuration) {
            return container
        }
        let local = ModelConfiguration(schema: schema, cloudKitDatabase: .none)
        do {
            return try ModelContainer(for: schema, configurations: local)
        } catch {
            fatalError("Couldn't open the settings store: \(error)")
        }
    }()

    var body: some Scene {
        WindowGroup {
            RootView()
                .environment(model)
                .environment(model.power)
                .foldPosture(model.posture)
                .preferredColorScheme(.dark)
                .tint(Palette.amber)
        }
        .modelContainer(container)
    }
}
