import Foundation
import GSXCore

/// Bộ điều kiện mà mọi định dạng đều phải qua trước khi tải.
///
/// Một chỗ duy nhất, thay vì mười lăm dòng `if` chép lại trong sáu file như bản
/// UIKit — nơi mà đúng hai lần kiểm tra UMP đã bị thiếu `return` và vẫn chạy
/// tiếp xuống lệnh tải.
@MainActor
enum AdGate {

    /// `nil` nghĩa là đi tiếp được.
    static func check(_ format: AdType, requiresConsent: Bool = true) -> AdError? {
        let kit = AdsKit.shared

        guard let configuration = kit.configuration else { return .notConfigured }
        guard configuration.isEnabled else { return .adsDisabled }
        guard !EntitlementCenter.shared.isAdsRemoved else { return .purchased }
        guard !configuration.ids(for: format).isEmpty else { return .noAdUnitId }
        guard NetworkMonitor.shared.isConnected else { return .noNetwork }
        if requiresConsent {
            guard ConsentManager.shared.canRequestAds else { return .consentNotObtained }
            guard kit.isReady else { return .sdkNotStarted }
        }
        return nil
    }
}
