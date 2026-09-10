import XCTest
import SwiftUI
@testable import GSXAds

/// Các đoạn mã trong README, chép nguyên văn.
///
/// Không kiểm hành vi — kiểm rằng chúng **biên dịch được**. Một tài liệu hướng
/// dẫn sai tên hàm còn tệ hơn không có tài liệu: người đọc tin nó, gõ theo, rồi
/// mất buổi sáng để phát hiện ra hàm đó chưa từng tồn tại.
@MainActor
final class READMESnippetsTests: XCTestCase {

    func test_mọiVíDụĐềuBiênDịchĐược() {
        XCTAssertNotNil(Self.self)
    }

    // MARK: - Mục 2: Khởi động

    private func mục2_khởiĐộng() {
        AdsKit.shared.configure(AdsConfiguration(
            units: AdUnits(
                appOpen:      ["ca-app-pub-.../..."],
                banner:       ["ca-app-pub-.../...", "ca-app-pub-.../..."],
                native:       ["ca-app-pub-.../..."],
                interstitial: ["ca-app-pub-.../..."],
                rewarded:     ["ca-app-pub-.../..."]
            ),
            appId: "ca-app-pub-XXXX~YYYY",
            isTestMode: true,
            isEnabled: true,
            collapsibleBanner: .bottom,
            interstitialPacing: InterstitialPacing(start: 2, loop: 3)
        ))
    }

    // MARK: - Mục 3: Đồng ý, ATT, quyền riêng tư

    private var mục3_formRiêngTư: some View {
        Group {
            if ConsentManager.shared.isPrivacyOptionsRequired {
                Button("Tuỳ chọn riêng tư") {
                    Task { await ConsentManager.shared.presentPrivacyOptions() }
                }
            }
        }
    }

    private func mục3_att() async {
        AdsKit.shared.configuration?.requestsAppTracking = false
        await ConsentManager.shared.requestTrackingAuthorization()
    }

    private func mục3_thửFormỞViệtNam() {
        #if DEBUG
        ConsentManager.shared.debugGeography = .EEA
        ConsentManager.shared.debugDeviceIdentifiers = ["ID_MÁY_LẤY_TRONG_LOG"]
        ConsentManager.shared.reset()
        #endif
    }

    // MARK: - Mục 4: Banner

    private var mục4_banner: some View {
        Color.clear
            .safeAreaInset(edge: .bottom) { BannerAd() }
            .overlay {
                BannerAd(slot: "home", size: .adaptive, collapsible: .bottom, reservesSpace: true)
            }
    }

    // MARK: - Mục 5: Native

    private var mục5_khuônDựngSẵn: some View {
        VStack {
            NativeAdSlot(slot: "feed", style: .medium)
            NativeAdSlot(slot: "feed", style: .medium, reservesSpace: true)
        }
    }

    private var mục5_đổiGiaoDiện: some View {
        Color.clear
            .nativeAdTheme(NativeAdTheme(
                background: Color(.secondarySystemBackground),
                cornerRadius: 16,
                headlineColor: .primary,
                ctaBackground: .accentColor,
                ctaForeground: .white,
                badgeText: "Quảng cáo"
            ))
    }

    private var mục5_tựViếtBốCục: some View {
        NativeAdSlot(slot: "feed") {
            VStack(alignment: .leading, spacing: 8) {
                NativeMedia(aspectRatio: 4 / 3)
                HStack(spacing: 10) {
                    NativeIcon(size: 40)
                    VStack(alignment: .leading) {
                        NativeHeadline(lines: 2)
                        NativeAdvertiser()
                    }
                    Spacer()
                    NativeAdBadge()
                }
                NativeBody(lines: 2)
                NativeCallToAction().frame(maxWidth: .infinity, minHeight: 44)
            }
            .padding(12)
        }
    }

    private func mục5_mọiMảnh() -> [any View] {
        [NativeHeadline(), NativeBody(), NativeIcon(), NativeMedia(),
         NativeCallToAction(), NativeAdvertiser(), NativeStarRating(),
         NativeStore(), NativePrice(), NativeAdBadge()]
    }

    private func mục5_tựQuảnViệcTải() {
        let native = NativeAdController(slot: "feed")
        native.load()
        native.reload()
        native.clear()
        _ = (native.ad, native.isReady, native.isLoading, native.lastError)
    }

    // MARK: - Mục 6: Interstitial

    private var mục6_interstitial: some View {
        Button("Xong") {
            Task {
                await AdsKit.shared.interstitial.show(slot: .exit)
            }
        }
        .preloadInterstitial(slot: .exit)
    }

    private func mục6_biếtLýDo() async {
        switch await AdsKit.shared.interstitial.show(slot: .exit) {
        case .shown:              print("đã xem")
        case .skipped(let lý_do): print("bỏ qua: \(lý_do.localizedDescription)")
        }
        await AdsKit.shared.interstitial.show(slot: .exit, pacing: .everyTime)
    }

    // MARK: - Mục 7: Rewarded

    private func mục7_rewarded() async {
        let result = await AdsKit.shared.rewarded.show(slot: "hint")
        if result.isEarned { print("thưởng") }

        switch result {
        case .earned(let amount, let type): print(amount, type)
        case .dismissed:                    print("đóng sớm")
        case .skipped(let lý_do):           print(lý_do.localizedDescription)
        }

        await AdsKit.shared.rewardedInterstitial.show(slot: "hint")
    }

    // MARK: - Mục 8: App Open

    private func mục8_appOpen() async {
        await AdsKit.shared.startAndShowLaunchAd()
        if UserDefaults.standard.bool(forKey: "hasSeenOnboarding") {
            await AdsKit.shared.startAndShowLaunchAd()
        } else {
            await AdsKit.shared.start()
        }
        AdsKit.shared.appOpen.prepare()
        await AdsKit.shared.appOpen.showIfAvailable()
    }

    private var mục8_tắtAppOpen: some View {
        Color.clear.gsxAds(appOpenOnForeground: false)
    }

    // MARK: - Mục 10: Mở khoá bằng quảng cáo

    @MainActor
    private enum Unlock {
        static var byWatchingAd = false

        static func feature(present paywall: () -> Void, then unlocked: @escaping () -> Void) async {
            if EntitlementCenter.shared.isAdsRemoved { return unlocked() }

            if byWatchingAd {
                await AdsKit.shared.interstitial.show(slot: .unlock, pacing: .everyTime)
                unlocked()
            } else {
                paywall()
            }
        }
    }

    // MARK: - Mục 11 và 12

    private func mục11_ghiNhậnDoanhThu() {
        AdsKit.shared.onEvent = { format, slot, event in
            guard case .paid(let revenue) = event else { return }
            _ = (format.analyticsName, slot, revenue.value, revenue.currencyCode,
                 revenue.adUnitId, revenue.precision, revenue.format)
        }
    }

    private func mục12_bậtTắtTừXa(adsEnabled: Bool, ids: [String], start: Int, loop: Int) {
        AdsKit.shared.configuration?.isEnabled = adsEnabled
        AdsKit.shared.configuration?.units.interstitial = ids
        AdsKit.shared.configuration?.interstitialPacing = InterstitialPacing(start: start, loop: loop)
    }

    // MARK: - Mục 14: Tham chiếu

    private func mục14_khoQuảngCáo() {
        let center = AdsKit.shared.interstitial
        center.preload(slot: .default)
        _ = center.isReady(slot: .default)
        center.invalidate(slot: .default)
        center.invalidateAll()
        center.resetPacing(slot: .default)

        _ = (AdsKit.shared.isReady,
             AdsKit.shared.presentation.isLoading,
             AdsKit.shared.presentation.isPresenting,
             AdsKit.shared.presentation.isBusy)

        _ = (EntitlementCenter.shared.isAdsRemoved,
             EntitlementCenter.shared.isPurchased,
             EntitlementCenter.shared.isAdsRemovedManually,
             NetworkMonitor.shared.isConnected,
             GSXLog.isEnabled)
        EntitlementCenter.shared.setPurchased(true)

        _ = AdError.timedOut.isFailure
        _ = AdError.pacing.localizedDescription
    }

    private var mục14_view: some View {
        Color.clear
            .gsxAds()
            .adsLoadingOverlay()
            .preloadRewarded(slot: "hint")
            .overlay { AdsLoadingOverlay() }
    }
}
