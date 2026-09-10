import Foundation
import StoreKit
import UIKit
import Observation
import GSXCore

/// Mua bán, gom về một chỗ.
///
/// Chỉ StoreKit 2. Không đọc receipt, không cần máy chủ: hỏi App Store xem tài
/// khoản Apple này đang sở hữu những gì, và câu trả lời đó là sự thật.
/// `Transaction.currentEntitlements` đã loại sẵn gói hết hạn và giao dịch đã
/// hoàn tiền, nên ở đây không có dòng nào phải tính ngày tháng.
///
/// ```swift
/// BillingKit.shared.configure(productIds: ["app.weekly", "app.yearly", "app.lifetime"])
/// BillingKit.shared.start()
/// ```
@MainActor
@Observable
public final class BillingKit {

    public static let shared = BillingKit()

    /// Các gói đã tải, theo đúng thứ tự khai trong `configure`.
    public private(set) var plans: [BillingPlan] = []

    /// Đã tải xong danh sách gói chưa. Màn hình bán hàng dựng trước khi App
    /// Store trả lời, nên dựa vào cờ này để hiện chỗ chờ thay vì một dấu gạch
    /// đứng mãi.
    public private(set) var isLoaded = false

    /// Đã mua gì đó chưa. Cùng lúc được chép sang `EntitlementCenter`, nơi tầng
    /// quảng cáo đọc.
    public private(set) var isPurchased = false

    /// Đang có một giao dịch hoặc một lần khôi phục dở dang — để nút tự khoá
    /// lại thay vì cho bấm hai lần thành hai giao dịch.
    public private(set) var isBusy = false

    /// Gọi sau khi một giao dịch đã được xác minh và ghi nhận. Chỗ để app gửi
    /// sự kiện doanh thu của mình đi.
    public var onPurchase: ((Product) -> Void)?

    private var productIds: [String] = []
    private var updates: Task<Void, Never>?

    private init() {}

    // MARK: - Khởi động

    public func configure(productIds: [String]) {
        self.productIds = productIds.filter { !$0.isEmpty }
    }

    /// Bắt đầu nghe trước khi tải bất cứ thứ gì.
    ///
    /// Cái nghe này phải sống lâu hơn mọi màn hình: một giao dịch có thể hoàn
    /// tất lúc app đang ở nền, hoặc được cha mẹ duyệt sau vài giờ qua Ask to
    /// Buy, và nó về đây bất cứ lúc nào chuyện đó xảy ra. Không có nó thì giao
    /// dịch không bao giờ được kết thúc và App Store cứ gửi lại mãi.
    public func start() {
        guard updates == nil else { return }
        updates = Task(priority: .background) { [weak self] in
            for await result in Transaction.updates {
                await self?.settle(result)
            }
        }
        Task { [weak self] in
            // Quyền lợi trước, danh sách gói sau. Cờ "đã mua" là thứ quyết định
            // có hiện quảng cáo hay không, và nó đọc được ngay tại máy; còn
            // danh sách gói thì phải đợi cửa hàng trả lời — có khi là đợi một
            // hộp thoại đăng nhập. Chờ cái sau để biết cái trước là bắt người
            // đã trả tiền nhìn quảng cáo thêm vài giây nữa.
            await self?.refreshEntitlements()
            await self?.load()
        }
    }

    public func load() async {
        guard !productIds.isEmpty else {
            GSXLog.error("[billing] chưa khai product id nào")
            isLoaded = true
            return
        }
        do {
            let loaded = try await Product.products(for: productIds)
            // Giữ đúng thứ tự đã khai, vì đó là thứ tự màn hình bán hàng bày ra.
            plans = productIds.compactMap { id in
                loaded.first { $0.id == id }.map(BillingPlan.init)
            }
            let missing = productIds.filter { id in !loaded.contains { $0.id == id } }
            if !missing.isEmpty {
                GSXLog.error("[billing] không có trong App Store Connect: \(missing.joined(separator: ", "))")
            }
        } catch {
            GSXLog.error("[billing] tải gói hỏng: \(error.localizedDescription)")
        }
        isLoaded = true
        await refreshEntitlements()
    }

    public func plan(_ productId: String) -> BillingPlan? {
        plans.first { $0.id == productId }
    }

    // MARK: - Mua

    public enum PurchaseOutcome: Sendable {
        case bought
        case cancelled
        /// Đang đợi người khác — Ask to Buy, hoặc ngân hàng xác nhận. Giao dịch
        /// sẽ về qua `Transaction.updates` nếu được duyệt.
        case pending
        case unavailable

        public var didBuy: Bool { self == .bought }
    }

    @discardableResult
    public func purchase(_ plan: BillingPlan) async -> PurchaseOutcome {
        await purchase(productId: plan.id)
    }

    @discardableResult
    public func purchase(productId: String) async -> PurchaseOutcome {
        guard let product = plans.first(where: { $0.id == productId })?.product else { return .unavailable }
        guard !isBusy else { return .cancelled }
        isBusy = true
        defer { isBusy = false }

        do {
            switch try await product.purchase() {
            case let .success(result):
                await settle(result)
                guard isPurchased else { return .unavailable }
                // Chỉ báo khi giao dịch đã được xác minh và ghi nhận — một giao
                // dịch không qua xác minh không phải doanh thu, và báo nó lên là
                // thổi phồng mọi con số tính từ đó.
                onPurchase?(product)
                return .bought
            case .userCancelled:
                return .cancelled
            case .pending:
                return .pending
            @unknown default:
                return .unavailable
            }
        } catch {
            GSXLog.error("[billing] mua hỏng: \(error.localizedDescription)")
            return .unavailable
        }
    }

    /// Đọc lại xem tài khoản Apple này đang sở hữu gì.
    ///
    /// Cố ý không gọi `AppStore.sync()` trước: nó bắt nhập mật khẩu, mà trường
    /// hợp thường gặp — cùng tài khoản, máy mới — thì quyền lợi đã có sẵn để
    /// đọc. Chỉ khi không thấy gì mới đáng phiền tới người dùng.
    @discardableResult
    public func restore() async -> Bool {
        guard !isBusy else { return isPurchased }
        isBusy = true
        defer { isBusy = false }

        await refreshEntitlements()
        if isPurchased { return true }

        try? await AppStore.sync()
        await refreshEntitlements()
        return isPurchased
    }

    /// Mở màn hình quản lý gói đăng ký của hệ thống.
    public func showManageSubscriptions() async {
        guard let scene = UIApplication.shared.connectedScenes
            .compactMap({ $0 as? UIWindowScene })
            .first(where: { $0.activationState == .foregroundActive })
        else { return }
        try? await AppStore.showManageSubscriptions(in: scene)
    }

    // MARK: - Quyền lợi

    public func refreshEntitlements() async {
        var owns = false
        for await result in Transaction.currentEntitlements {
            guard case let .verified(transaction) = result,
                  transaction.revocationDate == nil,
                  productIds.contains(transaction.productID)
            else { continue }
            owns = true
        }
        apply(isPurchased: owns)
    }

    /// Xác minh, ghi nhận, và — quan trọng — kết thúc giao dịch.
    ///
    /// Một giao dịch chưa kết thúc sẽ được gửi lại ở mỗi lần mở app, mãi mãi.
    private func settle(_ result: VerificationResult<Transaction>) async {
        guard case let .verified(transaction) = result else {
            GSXLog.error("[billing] bỏ qua giao dịch không xác minh được")
            return
        }
        await refreshEntitlements()
        await transaction.finish()
    }

    private func apply(isPurchased owns: Bool) {
        isPurchased = owns
        EntitlementCenter.shared.setPurchased(owns)
    }
}
