import Foundation

/// Chu kỳ thanh toán, tách hẳn khỏi StoreKit.
///
/// `Product.SubscriptionPeriod` không dựng ra được bằng tay, nên mọi phép tính
/// dựa vào nó cũng không kiểm được. Cùng một con số ở đây thì kiểm được — và
/// mấy con số này là thứ in thẳng lên màn hình bán hàng, chỗ sai một chữ số là
/// một đơn hoàn tiền.
public struct BillingPeriod: Equatable, Sendable {

    public enum Unit: Sendable { case day, week, month, year }

    public let unit: Unit
    public let value: Int

    public init(unit: Unit, value: Int) {
        self.unit = unit
        self.value = value
    }

    /// Số tuần xấp xỉ, để quy giá về cùng một thước đo.
    ///
    /// Tháng tính tròn 4 tuần và năm tính 52 — không chính xác tuyệt đối,
    /// nhưng đây là con số để *so sánh* hai gói, không phải để tính tiền.
    public var approximateWeeks: Int {
        switch unit {
        case .day:   return max(1, value / 7)
        case .week:  return value
        case .month: return value * 4
        case .year:  return value * 52
        }
    }

    public var localizedText: String {
        let name: String
        switch unit {
        case .day:   name = "ngày"
        case .week:  name = "tuần"
        case .month: name = "tháng"
        case .year:  name = "năm"
        }
        return "\(value) \(name)"
    }
}

/// Những phép tính của màn hình bán hàng.
public enum BillingMath {

    /// Loại gói, suy từ chu kỳ chứ không từ tên id — tên id sớm muộn cũng có
    /// ngày bị đặt khác đi.
    public static func kind(period: BillingPeriod?, isNonConsumable: Bool) -> BillingPlan.Kind {
        guard let period else { return isNonConsumable ? .lifetime : .other }
        switch (period.unit, period.value) {
        case (.day, 7), (.week, 1):  return .weekly
        case (.month, 1):            return .monthly
        case (.month, 3):            return .quarterly
        case (.month, 6):            return .semiAnnual
        case (.year, 1):             return .yearly
        default:                     return .other
        }
    }

    /// Giá quy về một tuần. `nil` với gói mua đứt — chia một khoản trọn đời cho
    /// số tuần là con số không có nghĩa gì.
    public static func pricePerWeek(_ price: Decimal, over period: BillingPeriod?) -> Decimal? {
        guard let period else { return nil }
        let weeks = period.approximateWeeks
        guard weeks > 0 else { return nil }
        return price / Decimal(weeks)
    }

    /// Rẻ hơn bao nhiêu phần trăm, khi cả hai đã quy về một tuần.
    ///
    /// `nil` khi không rẻ hơn — nhãn "tiết kiệm" chỉ được hiện khi có thật.
    public static func savingsPercent(weekly mine: Decimal?, comparedTo theirs: Decimal?) -> Int? {
        guard let mine, let theirs, theirs > 0, mine < theirs else { return nil }
        let ratio = (theirs - mine) / theirs
        return Int((ratio as NSDecimalNumber).doubleValue * 100)
    }
}
