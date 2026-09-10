import SwiftUI
import GoogleMobileAds
import GSXCore

/// Từng phần nội dung của một quảng cáo native.
public enum NativeAssetRole: Hashable, Sendable {
    case headline, body, icon, media, callToAction, advertiser, starRating, store, price
}

/// Chỗ nối giữa bố cục SwiftUI và `NativeAdView` của Google.
///
/// Google bắt buộc mỗi phần nội dung phải là một `UIView` thật, được gán vào
/// đúng thuộc tính của `NativeAdView`, và `nativeAd` phải gán **sau cùng** —
/// đó là cách SDK biết chỗ nào là tiêu đề, chỗ nào là nút, và đâu là vùng bấm
/// được. Bản UIKit đáp ứng điều đó bằng bốn file .xib với các `tag` đánh số.
///
/// Ở đây mỗi thành phần SwiftUI (`NativeHeadline`, `NativeMedia`, …) tự dựng
/// `UIView` của nó rồi ghi tên vào đây; khi bố cục đã dựng xong thì `commit()`
/// gán `nativeAd` một lần. Bố cục viết bằng SwiftUI thuần, mà vẫn đúng luật
/// đếm hiển thị và đếm bấm của Google.
@MainActor
final class NativeAdContext {

    let ad: NativeAd
    weak var adView: GoogleMobileAds.NativeAdView?

    private var registered: [NativeAssetRole: UIView] = [:]
    private var committedRoles: Set<NativeAssetRole> = []
    private var isCommitScheduled = false

    init(ad: NativeAd) {
        self.ad = ad
    }

    func register(_ view: UIView, as role: NativeAssetRole) {
        registered[role] = view
        bind(view, role)
        scheduleCommit()
    }

    private func bind(_ view: UIView, _ role: NativeAssetRole) {
        guard let adView else { return }
        switch role {
        case .headline:     adView.headlineView = view
        case .body:         adView.bodyView = view
        case .icon:         adView.iconView = view
        case .media:        adView.mediaView = view as? MediaView
        case .callToAction: adView.callToActionView = view
        case .advertiser:   adView.advertiserView = view
        case .starRating:   adView.starRatingView = view
        case .store:        adView.storeView = view
        case .price:        adView.priceView = view
        }
    }

    /// Các thành phần SwiftUI xuất hiện dần trong cùng một vòng bố cục, nên gán
    /// `nativeAd` ngay lúc cái đầu tiên đăng ký là gán khi mới có một nửa. Gộp
    /// lại một nhịp chạy rồi mới gán, và chỉ gán lại khi tập thành phần thật sự
    /// đổi.
    private func scheduleCommit() {
        guard !isCommitScheduled else { return }
        isCommitScheduled = true
        DispatchQueue.main.async { [weak self] in
            guard let self else { return }
            self.isCommitScheduled = false
            self.commit()
        }
    }

    func commit() {
        guard let adView else { return }
        let roles = Set(registered.keys)
        guard roles != committedRoles, !roles.isEmpty else { return }

        // Gán lại toàn bộ trước khi nối quảng cáo: một thành phần đăng ký sau
        // lần gán trước sẽ chưa có mặt trong `adView`.
        registered.forEach { bind($1, $0) }
        committedRoles = roles
        adView.nativeAd = ad
        GSXLog.debug("[native] nối \(roles.count) thành phần")
    }
}

// MARK: - Environment

private struct NativeAdContextKey: EnvironmentKey {
    static let defaultValue: NativeAdContext? = nil
}

extension EnvironmentValues {
    var nativeAdContext: NativeAdContext? {
        get { self[NativeAdContextKey.self] }
        set { self[NativeAdContextKey.self] = newValue }
    }
}

private struct NativeAdThemeKey: EnvironmentKey {
    static let defaultValue = NativeAdTheme()
}

public extension EnvironmentValues {
    /// Màu, phông và bo góc cho các mẫu native dựng sẵn.
    var nativeAdTheme: NativeAdTheme {
        get { self[NativeAdThemeKey.self] }
        set { self[NativeAdThemeKey.self] = newValue }
    }
}

public extension View {
    /// Đổi giao diện của mọi ô native bên trong.
    ///
    /// ```swift
    /// ContentView()
    ///     .nativeAdTheme(NativeAdTheme(ctaBackground: .accentColor, cornerRadius: 16))
    /// ```
    func nativeAdTheme(_ theme: NativeAdTheme) -> some View {
        environment(\.nativeAdTheme, theme)
    }
}
