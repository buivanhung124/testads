import Foundation

/// Toàn bộ id quảng cáo của một app, gom vào một chỗ.
///
/// Mỗi định dạng là **một danh sách**, không phải một id: SDK thử lần lượt từ
/// đầu danh sách, id nào không trả về quảng cáo thì rơi xuống id kế tiếp
/// (`AdWaterfall`). Chỉ có một id thì để một phần tử là xong.
public struct AdUnits: Sendable, Equatable {

    public var appOpen: [String]
    public var banner: [String]
    public var native: [String]
    public var interstitial: [String]
    public var rewarded: [String]
    public var rewardedInterstitial: [String]

    public init(
        appOpen: [String] = [],
        banner: [String] = [],
        native: [String] = [],
        interstitial: [String] = [],
        rewarded: [String] = [],
        rewardedInterstitial: [String] = []
    ) {
        self.appOpen = appOpen
        self.banner = banner
        self.native = native
        self.interstitial = interstitial
        self.rewarded = rewarded
        self.rewardedInterstitial = rewardedInterstitial
    }

    public func ids(for format: AdType) -> [String] {
        switch format {
        case .appOpen:              return appOpen
        case .banner:               return banner
        case .native:               return native
        case .interstitial:         return interstitial
        case .rewarded:             return rewarded
        case .rewardedInterstitial: return rewardedInterstitial
        }
    }

    /// Bộ id test công khai của Google.
    ///
    /// Dùng khi `AdsConfiguration.isTestMode` bật, để không bao giờ phải dán id
    /// test vào chỗ id thật rồi quên đổi lại lúc phát hành.
    public static let test = AdUnits(
        appOpen:              ["ca-app-pub-3940256099942544/5575463023"],
        banner:               ["ca-app-pub-3940256099942544/2934735716"],
        native:               ["ca-app-pub-3940256099942544/3986624511"],
        interstitial:         ["ca-app-pub-3940256099942544/4411468910"],
        rewarded:             ["ca-app-pub-3940256099942544/1712485313"],
        rewardedInterstitial: ["ca-app-pub-3940256099942544/6978759866"]
    )

    /// Id ứng dụng test của Google, để đối chiếu với `GADApplicationIdentifier`
    /// trong Info.plist.
    public static let testAppId = "ca-app-pub-3940256099942544~1458002511"
}
