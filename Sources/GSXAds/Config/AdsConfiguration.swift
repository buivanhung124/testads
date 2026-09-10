import Foundation
import UIKit

/// Mọi thứ có thể đổi mà không phải sửa code của SDK.
///
/// Truyền một lần ở `AdsKit.shared.configure(_:)`. Những cờ có thể đổi giữa
/// chừng phiên — bật/tắt quảng cáo từ Remote Config chẳng hạn — sửa thẳng trên
/// `AdsKit.shared.configuration`, và mọi định dạng đọc lại ở lần tải kế tiếp
/// chứ không giữ bản sao riêng.
public struct AdsConfiguration: Sendable {

    /// Id thật của app. Bộ id test được dùng thay khi `isTestMode` bật.
    public var units: AdUnits

    /// Id ứng dụng AdMob (`ca-app-pub-…~…`).
    ///
    /// Chỉ để đối chiếu: GMA đọc id này từ `GADApplicationIdentifier` trong
    /// Info.plist và không có cách đặt lúc chạy. Điền vào đây thì SDK báo khi
    /// hai bên lệch nhau, thay vì để bản sai lặng lẽ phát hành.
    public var appId: String?

    /// Bật thì dùng `AdUnits.test` và không đụng tới `units`.
    public var isTestMode: Bool

    /// Công tắc tổng. Tắt thì không một định dạng nào tải, không hỏi UMP, không
    /// hỏi ATT — vì cả hai thứ đó chỉ tồn tại để phục vụ quảng cáo.
    public var isEnabled: Bool

    /// Thiết bị test: quảng cáo thật nhưng luôn có hàng để lấp, và click không
    /// tính vào tài khoản. Lấy id trong log của GMA ở lần chạy đầu.
    public var testDeviceIdentifiers: [String]

    /// Xin quyền theo dõi (ATT) ngay sau khi form đồng ý đóng lại.
    ///
    /// Tự bỏ qua nếu Info.plist chưa khai `NSUserTrackingUsageDescription`.
    /// Tắt nếu app muốn tự chọn thời điểm hỏi — chẳng hạn hỏi ở cuối phần giới
    /// thiệu, nơi vừa kịp giải thích vì sao.
    public var requestsAppTracking: Bool

    /// Cỡ banner mặc định.
    public var bannerSize: BannerSize

    /// Banner co lại được (`collapsible`). Banner loại này mở cao hơn ô chứa và
    /// bung **lên trên**, nên trên màn hình có nội dung sát đáy thì cân nhắc.
    public var collapsibleBanner: CollapsibleBannerMode

    /// Nhịp hiện interstitial mặc định cho mọi vị trí chưa nói gì khác.
    public var interstitialPacing: InterstitialPacing

    /// Chờ tối đa bao lâu cho một quảng cáo toàn màn hình trước khi mở cổng và
    /// đi tiếp. Không có nó thì một lần tải không bao giờ trả lời sẽ treo màn
    /// hình chờ ngay trên đầu người đang chỉ muốn bấm nút back.
    public var fullScreenLoadTimeout: TimeInterval

    /// Quãng nghỉ tối thiểu giữa hai quảng cáo toàn màn hình.
    public var minimumFullScreenInterval: TimeInterval

    /// Quảng cáo App Open quá hạn thì bỏ, tải cái mới. Google khuyến nghị 4 giờ.
    public var appOpenExpiration: TimeInterval

    /// Có tự hiện App Open khi người dùng quay lại app hay không.
    public var showsAppOpenOnForeground: Bool

    /// Nhãn trên lớp phủ lúc chờ quảng cáo toàn màn hình.
    public var loadingText: String

    public init(
        units: AdUnits = AdUnits(),
        appId: String? = nil,
        isTestMode: Bool = false,
        isEnabled: Bool = true,
        testDeviceIdentifiers: [String] = [],
        requestsAppTracking: Bool = true,
        bannerSize: BannerSize = .adaptive,
        collapsibleBanner: CollapsibleBannerMode = .none,
        interstitialPacing: InterstitialPacing = .everyTime,
        fullScreenLoadTimeout: TimeInterval = 12,
        minimumFullScreenInterval: TimeInterval = 0,
        appOpenExpiration: TimeInterval = 4 * 3600,
        showsAppOpenOnForeground: Bool = true,
        loadingText: String = "Loading Ads..."
    ) {
        self.units = units
        self.appId = appId
        self.isTestMode = isTestMode
        self.isEnabled = isEnabled
        self.testDeviceIdentifiers = testDeviceIdentifiers
        self.requestsAppTracking = requestsAppTracking
        self.bannerSize = bannerSize
        self.collapsibleBanner = collapsibleBanner
        self.interstitialPacing = interstitialPacing
        self.fullScreenLoadTimeout = fullScreenLoadTimeout
        self.minimumFullScreenInterval = minimumFullScreenInterval
        self.appOpenExpiration = appOpenExpiration
        self.showsAppOpenOnForeground = showsAppOpenOnForeground
        self.loadingText = loadingText
    }

    /// Bộ id đang thực sự được dùng.
    public var activeUnits: AdUnits { isTestMode ? .test : units }

    public func ids(for format: AdType) -> [String] { activeUnits.ids(for: format) }
}

/// Cỡ ô banner.
public enum BannerSize: String, Sendable {

    /// Anchored adaptive cỡ lớn — cỡ Google khuyến nghị từ SDK 13.9.
    ///
    /// Chiều cao do Google tính theo bề rộng và máy, trong khoảng 50–150pt và
    /// không quá 20% chiều cao màn hình. Cao hơn banner 50pt đời cũ, và đó là
    /// chủ ý: banner cao hơn thì giá thầu cao hơn. Đây cũng là cỡ **duy nhất**
    /// nhận được quảng cáo co lại được.
    case adaptive

    /// 320×50 cố định. Chiếm ít chỗ nhất, nhưng không dùng được collapsible và
    /// giá thầu thấp hơn.
    case compact
}

/// Banner co lại được bung về phía nào.
public enum CollapsibleBannerMode: String, Sendable {
    /// Banner thường.
    case none
    /// Nút thu gọn ở mép trên, banner bung xuống dưới — cho banner đặt trên đầu.
    case top
    /// Nút thu gọn ở mép dưới, banner bung lên trên — cho banner đặt dưới đáy.
    case bottom
}

/// Bao lâu thì cho hiện interstitial một lần.
///
/// Giữ nguyên cách đếm của bản UIKit: `start` là lần thứ mấy thì hiện lần đầu,
/// sau đó cứ mỗi `loop` lần lại hiện. `start: 2, loop: 3` nghĩa là lần 2, 5, 8…
public struct InterstitialPacing: Sendable, Equatable {

    public var start: Int
    public var loop: Int

    public init(start: Int, loop: Int) {
        self.start = max(1, start)
        self.loop = max(1, loop)
    }

    /// Lần nào cũng hiện.
    public static let everyTime = InterstitialPacing(start: 1, loop: 1)

    /// Lượt thứ `count` (đếm từ 1) có phải lượt được hiện không.
    public func shouldShow(at count: Int) -> Bool {
        guard count >= start else { return false }
        return (count - start) % loop == 0
    }
}
