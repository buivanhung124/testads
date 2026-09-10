import SwiftUI
import GoogleMobileAds
import GSXCore

/// Ô banner.
///
/// Tự lo lấy phần khó: chờ SDK khởi động xong, đo bề rộng để lấy cỡ anchored
/// adaptive, tải lại khi xoay máy, và **tự biến mất** khi người dùng đã mua
/// hoặc khi quảng cáo đang tắt — không cần một dòng `if` nào ở phía màn hình.
///
/// ```swift
/// // Dính đáy, nằm ngoài vùng cuộn:
/// ContentView()
///     .safeAreaInset(edge: .bottom) { BannerAd() }
///
/// // Hoặc đặt thẳng vào bố cục:
/// VStack {
///     List { … }
///     BannerAd(slot: "home", collapsible: .bottom)
/// }
/// ```
public struct BannerAd: View {

    private let slot: AdSlot
    private let size: BannerSize?
    private let collapsible: CollapsibleBannerMode?
    private let reservesSpace: Bool

    @State private var measuredHeight: CGFloat?

    /// - Parameters:
    ///   - slot: tên vị trí, chỉ dùng để đọc log và thống kê.
    ///   - size: bỏ trống thì theo `configuration.bannerSize`.
    ///   - collapsible: bỏ trống thì theo `configuration.collapsibleBanner`.
    ///   - reservesSpace: giữ sẵn chỗ đúng bằng chiều cao banner trong lúc tải,
    ///     để nội dung không nhảy khi quảng cáo hiện ra. Tải hỏng thì chỗ đó
    ///     thu về 0.
    public init(
        slot: AdSlot = .default,
        size: BannerSize? = nil,
        collapsible: CollapsibleBannerMode? = nil,
        reservesSpace: Bool = true
    ) {
        self.slot = slot
        self.size = size
        self.collapsible = collapsible
        self.reservesSpace = reservesSpace
    }

    public var body: some View {
        if canShow {
            GeometryReader { proxy in
                BannerRepresentable(
                    slot: slot,
                    size: resolvedSize,
                    collapsible: collapsible ?? AdsKit.shared.configuration?.collapsibleBanner ?? .none,
                    width: proxy.size.width,
                    height: $measuredHeight
                )
            }
            .frame(height: resolvedHeight)
            .animation(.easeOut(duration: 0.2), value: resolvedHeight)
            .accessibilityHidden(measuredHeight == nil)
        }
    }

    /// Đọc thẳng từ `AdsKit` và `EntitlementCenter`, cả hai đều `@Observable`,
    /// nên một giao dịch giữa chừng phiên làm ô này biến mất ngay mà không cần
    /// khởi động lại app.
    private var canShow: Bool {
        guard let configuration = AdsKit.shared.configuration else { return false }
        return configuration.isEnabled
            && !configuration.ids(for: .banner).isEmpty
            && !EntitlementCenter.shared.isAdsRemoved
            && AdsKit.shared.isReady
    }

    private var resolvedHeight: CGFloat {
        if let measuredHeight { return measuredHeight }
        return reservesSpace ? estimatedHeight : 0
    }

    /// Chiều cao dự kiến, đo theo bề rộng cửa sổ. Chỉ dùng cho khoảng chỗ giữ
    /// trước — con số thật do quảng cáo tải về quyết định.
    private var estimatedHeight: CGFloat {
        guard resolvedSize == .adaptive else { return AdSizeBanner.size.height }
        let width = TopViewController.keyWindow?.bounds.width ?? UIScreen.main.bounds.width
        guard width > 0 else { return 0 }
        if width >= AdSizeLeaderboard.size.width { return AdSizeLeaderboard.size.height }
        return largeAnchoredAdaptiveBanner(width: width).size.height
    }

    private var resolvedSize: BannerSize {
        size ?? AdsKit.shared.configuration?.bannerSize ?? .adaptive
    }
}

private struct BannerRepresentable: UIViewControllerRepresentable {

    let slot: AdSlot
    let size: BannerSize
    let collapsible: CollapsibleBannerMode
    let width: CGFloat
    @Binding var height: CGFloat?

    func makeUIViewController(context: Context) -> BannerHostController {
        let controller = BannerHostController()
        controller.onHeightChange = { newHeight in
            height = newHeight > 0 ? newHeight : 0
        }
        controller.update(slot: slot, collapsible: collapsible, size: size, width: width)
        return controller
    }

    func updateUIViewController(_ controller: BannerHostController, context: Context) {
        controller.update(slot: slot, collapsible: collapsible, size: size, width: width)
    }
}
