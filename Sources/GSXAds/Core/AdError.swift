import Foundation

/// Vì sao một lần gọi quảng cáo không đi tới đâu.
///
/// Giữ nguyên bộ lý do của bản UIKit, vì đó là những câu hỏi thật sự hữu ích
/// lúc soi log: không phải lỗi nào cũng là lỗi — "người này đã mua" và "app
/// đang tắt quảng cáo" là hoạt động đúng, chỉ là không có quảng cáo nào hiện.
public enum AdError: Error, Sendable, Equatable {

    /// Chưa gọi `AdsKit.shared.configure(_:)`.
    case notConfigured
    /// `configuration.isEnabled` đang tắt.
    case adsDisabled
    /// Định dạng này không có id nào.
    case noAdUnitId
    /// Không có mạng.
    case noNetwork
    /// UMP chưa cho phép yêu cầu quảng cáo.
    case consentNotObtained
    /// `MobileAds.start()` chưa chạy xong.
    case sdkNotStarted
    /// Người dùng đã mua — không hiện quảng cáo nữa.
    case purchased
    /// Đang tải chính định dạng/vị trí đó.
    case alreadyLoading
    /// Đã có sẵn một quảng cáo chưa dùng.
    case alreadyLoaded
    /// Một quảng cáo toàn màn hình khác đang hiện.
    case alreadyPresenting
    /// Chưa tới lượt theo `InterstitialPacing`.
    case pacing
    /// Chưa hết quãng nghỉ `minimumFullScreenInterval`.
    case tooSoon
    /// Hết thời gian chờ.
    case timedOut
    /// Không tìm được màn hình để hiện quảng cáo lên.
    case noPresenter
    /// Lỗi từ Google Mobile Ads.
    case google(String)

    public var isFailure: Bool {
        switch self {
        case .adsDisabled, .purchased, .pacing, .tooSoon: return false
        default: return true
        }
    }

    public var localizedDescription: String {
        switch self {
        case .notConfigured:      return "AdsKit chưa được configure"
        case .adsDisabled:        return "Quảng cáo đang tắt"
        case .noAdUnitId:         return "Không có ad unit id"
        case .noNetwork:          return "Không có mạng"
        case .consentNotObtained: return "UMP chưa cho phép yêu cầu quảng cáo"
        case .sdkNotStarted:      return "Google Mobile Ads chưa start"
        case .purchased:          return "Người dùng đã mua"
        case .alreadyLoading:     return "Đang tải"
        case .alreadyLoaded:      return "Đã có quảng cáo sẵn"
        case .alreadyPresenting:  return "Đang hiện một quảng cáo toàn màn hình khác"
        case .pacing:             return "Chưa tới lượt hiện"
        case .tooSoon:            return "Chưa hết quãng nghỉ giữa hai quảng cáo"
        case .timedOut:           return "Hết thời gian chờ"
        case .noPresenter:        return "Không tìm thấy view controller để hiện"
        case .google(let message): return message
        }
    }
}
