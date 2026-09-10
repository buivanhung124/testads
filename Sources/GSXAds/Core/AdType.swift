import Foundation

/// Sáu định dạng SDK biết tải.
public enum AdType: String, Sendable, CaseIterable {
    case banner
    case native
    case interstitial
    case rewarded
    case rewardedInterstitial
    case appOpen

    /// Tên gửi kèm sự kiện doanh thu, đúng chuỗi GA4 vẫn dùng.
    public var analyticsName: String {
        switch self {
        case .banner:               return "Banner"
        case .native:               return "Native"
        case .interstitial:         return "Interstitial"
        case .rewarded:             return "Rewarded"
        case .rewardedInterstitial: return "RewardedInterstitial"
        case .appOpen:              return "AppOpen"
        }
    }

    var isFullScreen: Bool {
        switch self {
        case .banner, .native: return false
        default: return true
        }
    }
}
