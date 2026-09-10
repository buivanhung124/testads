import Foundation
import Observation

/// Người dùng đã trả tiền hay chưa — và đó là thứ duy nhất tắt quảng cáo.
///
/// Đứng ở `GSXCore` để `GSXAds` đọc được mà không phải biết gì về StoreKit,
/// còn `GSXBilling` là bên duy nhất được ghi. App không dùng `GSXBilling`
/// (dùng RevenueCat, Adapty, server riêng…) thì gọi thẳng `setPurchased(_:)`.
///
/// Cố ý **không** suy ra từ cờ cấu hình nào khác: một app đang tắt bán hàng
/// không có nghĩa là được dùng bản không quảng cáo — chỉ giao dịch thật mới
/// bật cờ này.
@MainActor
@Observable
public final class EntitlementCenter {

    public static let shared = EntitlementCenter()

    private let purchasedKey = "gsx.entitlement.isPurchased"
    private let defaults: UserDefaults

    /// Lưu lại giữa các lần mở app để lần khởi động sau không loé quảng cáo
    /// trong lúc StoreKit còn đang trả lời.
    public private(set) var isPurchased: Bool

    /// Gỡ quảng cáo bằng đường khác — thưởng, mã khuyến mãi, cờ nội bộ.
    /// Tách khỏi `isPurchased` vì nó không phải một giao dịch.
    public var isAdsRemovedManually = false

    /// Câu hỏi mà mọi định dạng quảng cáo đều hỏi trước khi tải.
    public var isAdsRemoved: Bool { isPurchased || isAdsRemovedManually }

    init(defaults: UserDefaults = .standard) {
        self.defaults = defaults
        self.isPurchased = defaults.bool(forKey: purchasedKey)
    }

    /// Chỉ `GSXBilling` (hoặc lớp thanh toán của app) được gọi.
    public func setPurchased(_ value: Bool) {
        guard isPurchased != value else { return }
        isPurchased = value
        defaults.set(value, forKey: purchasedKey)
        GSXLog.debug("[entitlement] isPurchased = \(value)")
    }
}
