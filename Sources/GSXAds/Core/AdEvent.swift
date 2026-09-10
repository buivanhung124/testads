import Foundation
import GoogleMobileAds

/// Một lượt quảng cáo báo về.
public enum AdEvent: Sendable {
    case loaded
    case failed(AdError)
    case impression
    case click
    case opened
    case closed
    case rewarded(amount: Int, type: String)
    case paid(AdRevenue)
}

/// Doanh thu của một lượt hiện.
///
/// SDK không tự gửi đi đâu cả — không kéo Firebase vào chỉ để làm việc đó.
/// App bắt ở `AdsKit.shared.onEvent` rồi log bằng cách của mình (GA4
/// `ad_impression`, ASA keyword, AppsFlyer…).
public struct AdRevenue: Sendable {
    public let value: Double
    public let currencyCode: String
    public let precision: String
    public let adUnitId: String
    public let format: AdType
}

/// Nơi một quảng cáo được đặt: `"feed"`, `"exit"`, `"unlock"`…
///
/// Đặt tên vị trí thay vì đếm bằng số như `tag` bên UIKit — log đọc ra nghĩa
/// ngay, và nhịp hiện interstitial được đếm riêng cho từng vị trí.
public typealias AdSlot = String

public extension AdSlot {
    static let `default` = "default"
    /// Vị trí dùng chung cho các màn hình có quảng cáo lúc thoát ra.
    static let exit = "exit"
    /// Vị trí đổi một lần xem quảng cáo lấy một tính năng bị khoá.
    static let unlock = "unlock"
}

/// Báo doanh thu về `AdsKit` từ bất kỳ luồng nào.
///
/// `paidEventHandler` của GMA gần như luôn được gọi trên luồng chính, nhưng
/// "gần như" là không đủ để gọi thẳng vào một đối tượng `@MainActor` — sai một
/// lần là app đổ. Đẩy qua hàng đợi chính rồi mới vào.
func reportPaidEvent(_ value: AdValue, format: AdType, slot: AdSlot, unitId: String) {
    DispatchQueue.main.async {
        MainActor.assumeIsolated {
            AdsKit.shared.reportPaid(value, format: format, slot: slot, unitId: unitId)
        }
    }
}
