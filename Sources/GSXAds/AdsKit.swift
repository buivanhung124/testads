import UIKit
import Observation
import GoogleMobileAds
import GSXCore

/// Cửa vào duy nhất của tầng quảng cáo.
///
/// App chỉ chạm tới lớp này và các View trong `GSXAds`; những thứ còn lại là
/// việc bên trong. Cách dùng ngắn nhất:
///
/// ```swift
/// @main struct MyApp: App {
///     init() {
///         AdsKit.shared.configure(.init(
///             units: AdUnits(banner: [...], interstitial: [...]),
///             isTestMode: true
///         ))
///     }
///     var body: some Scene {
///         WindowGroup {
///             RootView().gsxAds()      // start SDK + xin consent + lớp phủ + App Open
///         }
///     }
/// }
/// ```
@MainActor
@Observable
public final class AdsKit {

    public static let shared = AdsKit()

    /// Cấu hình đang chạy. Sửa thẳng vào đây khi Remote Config trả lời — mọi
    /// định dạng đọc lại ở lần tải kế tiếp, không giữ bản sao riêng.
    public var configuration: AdsConfiguration?

    /// SDK đã khởi động và đã hỏi xong đồng ý. Banner và native chờ cờ này:
    /// gọi sớm hơn thì `canRequestAds` vẫn còn `false` và ô quảng cáo hỏng ngay
    /// trước khi kịp có cơ hội nào.
    public private(set) var isReady = false

    /// Trạng thái quảng cáo toàn màn hình, cho lớp phủ chờ và cho việc chặn hai
    /// quảng cáo chồng lên nhau.
    public let presentation = AdsPresentationState()

    /// Mọi sự kiện của mọi định dạng đi qua đây.
    ///
    /// SDK cố ý không tự gửi doanh thu đi đâu — gắn Firebase vào một package
    /// quảng cáo là bắt mọi app phải kéo theo Firebase. App tự log ở đây:
    ///
    /// ```swift
    /// AdsKit.shared.onEvent = { format, slot, event in
    ///     if case .paid(let revenue) = event { logAsaAdRevenue(revenue) }
    /// }
    /// ```
    public var onEvent: ((AdType, AdSlot, AdEvent) -> Void)?

    public let interstitial = InterstitialCenter()
    public let rewarded = RewardedCenter()
    public let rewardedInterstitial = RewardedInterstitialCenter()
    public let appOpen = AppOpenCenter()

    private var startTask: Task<Void, Never>?

    private init() {}

    // MARK: - Khởi động

    public func configure(_ configuration: AdsConfiguration) {
        self.configuration = configuration
        GSXLog.debug("[ads] configure — test=\(configuration.isTestMode), enabled=\(configuration.isEnabled)")
    }

    /// Xin đồng ý trước, rồi mới bật SDK.
    ///
    /// Cả hai chỉ chạy khi quảng cáo đang bật: UMP và ATT sinh ra để phục vụ
    /// quảng cáo, và xin theo dõi trong một app không hiện quảng cáo nào là một
    /// lời xin không có gì đằng sau — cũng đúng là thứ App Review soi.
    ///
    /// Gọi bao nhiêu lần cũng được, chỉ chạy một lần thật.
    public func start(from viewController: UIViewController? = nil) async {
        guard let configuration, configuration.isEnabled else { return }
        guard !EntitlementCenter.shared.isAdsRemoved else { return }

        if let startTask { return await startTask.value }

        let task = Task { @MainActor in
            warnIfAppIdDisagrees(configuration)

            await ConsentManager.shared.gather(from: viewController)

            // ATT sau UMP, không phải cùng lúc: xem `requestTrackingAuthorization`.
            if configuration.requestsAppTracking {
                await ConsentManager.shared.requestTrackingAuthorization()
            }

            if !configuration.testDeviceIdentifiers.isEmpty {
                MobileAds.shared.requestConfiguration.testDeviceIdentifiers = configuration.testDeviceIdentifiers
            }

            await MobileAds.shared.start()

            isReady = true
            GSXLog.debug("[ads] Google Mobile Ads đã start")
        }
        startTask = task
        await task.value
    }

    /// Khởi động rồi hiện quảng cáo mở app cho **lần mở từ đầu** — dùng ở màn
    /// hình splash, nơi có người đang đợi.
    ///
    /// ```swift
    /// .task {
    ///     await AdsKit.shared.startAndShowLaunchAd()
    ///     goToHome()
    /// }
    /// ```
    ///
    /// Luôn trả lời, kể cả khi quảng cáo tắt hoặc tải hỏng, nên màn splash cứ
    /// `await` rồi đi tiếp.
    public func startAndShowLaunchAd(from viewController: UIViewController? = nil) async {
        await start(from: viewController)
        await appOpen.showOnLaunch(from: viewController)
    }

    /// GMA đọc id ứng dụng từ `GADApplicationIdentifier` trong Info.plist và
    /// không có cách đặt lúc chạy, nên `configuration.appId` chỉ để đối chiếu.
    /// Lệch nhau thì nói ra, thay vì để bản sai lặng lẽ phát hành.
    private func warnIfAppIdDisagrees(_ configuration: AdsConfiguration) {
        let wanted = configuration.isTestMode ? AdUnits.testAppId : configuration.appId
        guard let wanted, !wanted.isEmpty else { return }
        let configured = Bundle.main.object(forInfoDictionaryKey: "GADApplicationIdentifier") as? String
        guard let configured else {
            GSXLog.error("[ads] Info.plist thiếu GADApplicationIdentifier — GMA sẽ không chạy")
            return
        }
        guard wanted != configured else { return }
        GSXLog.error("[ads] lệch app id: config nói \(wanted), Info.plist nói \(configured) — Info.plist thắng")
    }

    // MARK: - Dùng bên trong

    /// Một `Request` mới. Banner co lại được đăng ký thêm tham số ở chỗ gọi.
    func makeRequest() -> Request {
        Request()
    }

    func emit(_ format: AdType, _ slot: AdSlot, _ event: AdEvent) {
        switch event {
        case .failed(let error) where !error.isFailure:
            GSXLog.debug("[\(format.rawValue):\(slot)] bỏ qua — \(error.localizedDescription)")
        case .failed(let error):
            GSXLog.error("[\(format.rawValue):\(slot)] hỏng — \(error.localizedDescription)")
        default:
            GSXLog.debug("[\(format.rawValue):\(slot)] \(event)")
        }
        onEvent?(format, slot, event)
    }

    /// Gắn vào `paidEventHandler` của mọi quảng cáo, ngay lúc dựng chứ không
    /// đợi callback "đã tải": banner co lại được có thể bắn sự kiện doanh thu
    /// trước lượt delegate đó, gắn muộn là mất lượt ghi đầu tiên.
    /// Độ chính xác của con số doanh thu, thành chữ — GA4 và các bên đo đạc
    /// đều nhận chuỗi chứ không nhận enum của GMA.
    private static func name(for precision: AdValuePrecision) -> String {
        switch precision {
        case .unknown:            return "unknown"
        case .estimated:          return "estimated"
        case .publisherProvided:  return "publisherProvided"
        case .precise:            return "precise"
        @unknown default:         return "unknown"
        }
    }

    func reportPaid(_ value: AdValue, format: AdType, slot: AdSlot, unitId: String) {
        emit(format, slot, .paid(AdRevenue(
            value: value.value.doubleValue,
            currencyCode: value.currencyCode,
            precision: Self.name(for: value.precision),
            adUnitId: unitId,
            format: format
        )))
    }
}

/// Trạng thái chung của quảng cáo toàn màn hình.
///
/// Thay cho biến toàn cục `isShowPopupLoadingAds` của bản UIKit: cùng nhiệm vụ
/// — không cho hai quảng cáo toàn màn hình chồng lên nhau — nhưng ở trong một
/// đối tượng `@MainActor` mà SwiftUI quan sát được, nên lớp phủ chờ cũng đọc
/// thẳng từ đây.
@MainActor
@Observable
public final class AdsPresentationState {

    /// Đang chờ tải một quảng cáo toàn màn hình mà người dùng đang đợi.
    public internal(set) var isLoading = false

    /// Một quảng cáo toàn màn hình đang hiện.
    public internal(set) var isPresenting = false

    /// Nhãn hiện trên lớp phủ.
    public internal(set) var loadingText = ""

    /// Lần gần nhất một quảng cáo toàn màn hình đóng lại, để tính quãng nghỉ.
    var lastDismissedAt: Date?

    /// Đang bận theo bất kỳ nghĩa nào.
    public var isBusy: Bool { isLoading || isPresenting }

    func canStartFullScreen(minimumInterval: TimeInterval) -> AdError? {
        if isBusy { return .alreadyPresenting }
        guard minimumInterval > 0, let last = lastDismissedAt else { return nil }
        return Date().timeIntervalSince(last) < minimumInterval ? .tooSoon : nil
    }
}
