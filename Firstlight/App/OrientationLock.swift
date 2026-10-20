import UIKit

/// Holds the night sideways on a Duo, so a bump in the dark can't rotate the light off the top half.
/// The rest of the app rotates freely.
enum OrientationLock {
    @MainActor static var allowed: UIInterfaceOrientationMask = .allButUpsideDown

    @MainActor
    static func landscape() {
        apply(.landscape)
    }

    @MainActor
    static func release() {
        apply(.allButUpsideDown)
    }

    @MainActor
    private static func apply(_ mask: UIInterfaceOrientationMask) {
        guard allowed != mask else { return }
        allowed = mask
        for scene in UIApplication.shared.connectedScenes.compactMap({ $0 as? UIWindowScene }) {
            scene.windows.first?.rootViewController?.setNeedsUpdateOfSupportedInterfaceOrientations()
            scene.requestGeometryUpdate(.iOS(interfaceOrientations: mask))
        }
    }
}

final class AppDelegate: NSObject, UIApplicationDelegate {
    func application(_ application: UIApplication, supportedInterfaceOrientationsFor window: UIWindow?) -> UIInterfaceOrientationMask {
        OrientationLock.allowed
    }
}
