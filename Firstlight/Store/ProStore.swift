import Observation
import StoreKit

/// Firstlight Pro: a single non-consumable unlock.
@MainActor
@Observable
final class ProStore {
    static let productID = "app.firstlight.pro"

    enum PurchaseState: Equatable {
        case idle
        case purchasing
        case pending
        case failed(String)
    }

    private(set) var product: Product?
    private(set) var isPro = false
    private(set) var purchaseState: PurchaseState = .idle

    @ObservationIgnored private var updatesTask: Task<Void, Never>?

    var displayPrice: String {
        product?.displayPrice ?? "$3.99"
    }

    func start() async {
        guard updatesTask == nil else { return }
        updatesTask = Task { [weak self] in
            for await update in Transaction.updates {
                if case .verified(let transaction) = update {
                    await transaction.finish()
                }
                await self?.refreshEntitlements()
            }
        }
        do {
            product = try await Product.products(for: [Self.productID]).first
        } catch {
            product = nil
        }
        await refreshEntitlements()
    }

    func refreshEntitlements() async {
        var unlocked = false
        for await result in Transaction.currentEntitlements {
            if case .verified(let transaction) = result,
               transaction.productID == Self.productID,
               transaction.revocationDate == nil {
                unlocked = true
            }
        }
        isPro = unlocked
    }

    func purchase() async {
        guard let product else {
            purchaseState = .failed("The App Store isn't reachable right now.")
            return
        }
        purchaseState = .purchasing
        do {
            switch try await product.purchase() {
            case .success(let verification):
                if case .verified(let transaction) = verification {
                    await transaction.finish()
                }
                await refreshEntitlements()
                purchaseState = .idle
            case .pending:
                purchaseState = .pending
            case .userCancelled:
                purchaseState = .idle
            @unknown default:
                purchaseState = .idle
            }
        } catch {
            purchaseState = .failed(error.localizedDescription)
        }
    }

    func restore() async {
        try? await AppStore.sync()
        await refreshEntitlements()
    }
}
