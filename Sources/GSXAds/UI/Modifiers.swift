import SwiftUI
import GSXCore

public extension View {

    /// Bật toàn bộ tầng quảng cáo cho app.
    ///
    /// Gắn một lần ở View gốc. Nó lo:
    /// - xin đồng ý (UMP) rồi khởi động Google Mobile Ads,
    /// - dựng màn chờ cho quảng cáo toàn màn hình,
    /// - tải sẵn và hiện quảng cáo App Open mỗi lần người dùng quay lại app.
    ///
    /// ```swift
    /// WindowGroup {
    ///     RootView().gsxAds()
    /// }
    /// ```
    ///
    /// - Parameter appOpenOnForeground: tắt nếu app muốn tự quyết định lúc nào
    ///   hiện quảng cáo mở app.
    func gsxAds(appOpenOnForeground: Bool = true) -> some View {
        modifier(GSXAdsRootModifier(appOpenOnForeground: appOpenOnForeground))
    }

    /// Chỉ gắn màn chờ, khi app tự lo phần khởi động.
    func adsLoadingOverlay() -> some View {
        overlay { AdsLoadingOverlay() }
    }

    /// Tải sẵn một quảng cáo xen kẽ khi màn hình này hiện ra.
    ///
    /// Đặt ở màn hình mà lối *ra* có quảng cáo: tới lúc bấm back thì quảng cáo
    /// đã nằm sẵn, không ai phải nhìn màn chờ.
    ///
    /// ```swift
    /// DetailView()
    ///     .preloadInterstitial(slot: .exit)
    /// ```
    func preloadInterstitial(slot: AdSlot = .default) -> some View {
        onAppear { AdsKit.shared.interstitial.preload(slot: slot) }
    }

    /// Tải sẵn một quảng cáo có thưởng khi màn hình này hiện ra.
    func preloadRewarded(slot: AdSlot = .default) -> some View {
        onAppear { AdsKit.shared.rewarded.preload(slot: slot) }
    }
}

private struct GSXAdsRootModifier: ViewModifier {

    let appOpenOnForeground: Bool

    @Environment(\.scenePhase) private var scenePhase
    @State private var hasStarted = false
    @State private var wasBackgrounded = false

    func body(content: Content) -> some View {
        content
            .overlay { AdsLoadingOverlay() }
            .task {
                guard !hasStarted else { return }
                hasStarted = true
                await AdsKit.shared.start()
                // Sau khi mọi thứ đã dựng xong mới tải quảng cáo mở app: làm
                // sớm hơn là tranh luồng chính với màn hình đầu tiên, mà cái
                // này là quảng cáo cho lần *quay lại* chứ không phải lần mở.
                AdsKit.shared.appOpen.prepare()
            }
            .onChange(of: scenePhase) { _, phase in
                switch phase {
                case .background:
                    wasBackgrounded = true
                case .active:
                    guard appOpenOnForeground, wasBackgrounded else { return }
                    wasBackgrounded = false
                    Task { await AdsKit.shared.appOpen.showIfAvailable() }
                default:
                    break
                }
            }
            .onChange(of: EntitlementCenter.shared.isAdsRemoved) { _, removed in
                // Vừa mua xong: bỏ hết quảng cáo đang giữ, để không có cái nào
                // nhảy ra sau khi người ta vừa trả tiền để khỏi phải xem.
                guard removed else { return }
                AdsKit.shared.interstitial.invalidateAll()
                AdsKit.shared.rewarded.invalidateAll()
                AdsKit.shared.rewardedInterstitial.invalidateAll()
                AdsKit.shared.appOpen.invalidateAll()
            }
    }
}
