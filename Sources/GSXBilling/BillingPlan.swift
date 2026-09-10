import Foundation
import StoreKit

/// Một gói bán, kèm những thứ màn hình bán hàng cần mà `Product` không đưa
/// thẳng ra.
///
/// Giá **không bao giờ** được viết cứng trong code: mọi con số ở đây đều đi ra
/// từ `Product`, đã được App Store định dạng theo đúng cửa hàng và đồng tiền
/// người mua đang dùng. Một giá sai trên màn hình bán hàng là một đơn hoàn tiền.
public struct BillingPlan: Identifiable, Sendable {

    public let product: Product
    public var id: String { product.id }

    public init(product: Product) {
        self.product = product
    }

    public var displayName: String { product.displayName }
    public var displayPrice: String { product.displayPrice }
    public var productDescription: String { product.description }

    public var isSubscription: Bool { product.subscription != nil }

    /// Chu kỳ thanh toán, đã tách khỏi kiểu của StoreKit — xem `BillingPeriod`.
    public var period: BillingPeriod? {
        product.subscription.map { Self.period(from: $0.subscriptionPeriod) }
    }

    /// Loại gói, đọc từ chính chu kỳ mà App Store Connect khai — không phải từ
    /// tên id, thứ luôn có ngày bị đặt khác đi.
    public var kind: Kind {
        BillingMath.kind(period: period, isNonConsumable: product.type == .nonConsumable)
    }

    public enum Kind: String, Sendable {
        case weekly, monthly, quarterly, semiAnnual, yearly, lifetime, other
    }

    /// Có bản dùng thử miễn phí không.
    public var hasFreeTrial: Bool {
        product.subscription?.introductoryOffer?.paymentMode == .freeTrial
    }

    /// Câu mô tả ưu đãi đầu, ví dụ "3 ngày miễn phí".
    public var introductoryOfferText: String? {
        guard let offer = product.subscription?.introductoryOffer else { return nil }
        let period = Self.period(from: offer.period).localizedText
        switch offer.paymentMode {
        case .freeTrial:  return "\(period) miễn phí"
        case .payAsYouGo: return "\(offer.displayPrice)/\(period)"
        case .payUpFront: return "\(offer.displayPrice) cho \(period) đầu"
        default:          return nil
        }
    }

    /// Giá quy về một tuần, để đặt cạnh gói tuần cho dễ so.
    public var pricePerWeek: String? {
        guard let perWeek = weeklyPrice else { return nil }
        return perWeek.formatted(product.priceFormatStyle)
    }

    /// Phần trăm rẻ hơn so với một gói khác khi quy về cùng một tuần.
    ///
    /// Dùng để in nhãn "tiết kiệm 60%" — và chỉ in khi con số này thật sự tồn
    /// tại, chứ không phải một con số đẹp chọn sẵn.
    public func savingsPercent(comparedTo other: BillingPlan) -> Int? {
        BillingMath.savingsPercent(weekly: weeklyPrice, comparedTo: other.weeklyPrice)
    }

    private var weeklyPrice: Decimal? {
        BillingMath.pricePerWeek(product.price, over: period)
    }

    private static func period(from period: Product.SubscriptionPeriod) -> BillingPeriod {
        let unit: BillingPeriod.Unit
        switch period.unit {
        case .day:   unit = .day
        case .week:  unit = .week
        case .month: unit = .month
        case .year:  unit = .year
        @unknown default: unit = .day
        }
        return BillingPeriod(unit: unit, value: period.value)
    }
}
