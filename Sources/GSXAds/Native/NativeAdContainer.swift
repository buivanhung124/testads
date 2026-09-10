import SwiftUI
import GoogleMobileAds

/// Bọc bố cục SwiftUI vào trong `NativeAdView` của Google.
///
/// Là `UIViewControllerRepresentable` chứ không phải `UIViewRepresentable` để
/// bố cục bên trong nằm trong một `UIHostingController` thật — nhờ vậy nó thừa
/// hưởng đúng giao diện sáng/tối, cỡ chữ và vùng an toàn của màn hình chứa nó.
struct NativeAdContainer<Content: View>: UIViewControllerRepresentable {

    let ad: NativeAd
    let theme: NativeAdTheme
    @ViewBuilder let content: Content

    func makeUIViewController(context: Context) -> NativeAdHostController {
        let controller = NativeAdHostController()
        controller.install(ad: ad, content: wrapped(with:))
        return controller
    }

    func updateUIViewController(_ controller: NativeAdHostController, context: Context) {
        controller.install(ad: ad, content: wrapped(with:))
    }

    func sizeThatFits(
        _ proposal: ProposedViewSize,
        uiViewController controller: NativeAdHostController,
        context: Context
    ) -> CGSize? {
        guard let width = proposal.width, width > 0 else { return nil }
        return controller.fittingSize(width: width)
    }

    /// Environment không tự chảy qua ranh giới UIKit, nên chủ đề và đầu nối
    /// quảng cáo được đặt lại vào bố cục ở đây.
    private func wrapped(with adContext: NativeAdContext) -> AnyView {
        AnyView(
            content
                .environment(\.nativeAdContext, adContext)
                .environment(\.nativeAdTheme, theme)
        )
    }
}

/// Màn hình con mang một quảng cáo native.
@MainActor
final class NativeAdHostController: UIViewController {

    private var adView: NativeAdCanvas?
    private var host: UIHostingController<AnyView>?
    private var adContext: NativeAdContext?
    private var installedAd: NativeAd?

    func install(ad: NativeAd, content: (NativeAdContext) -> AnyView) {
        // Cùng một quảng cáo thì chỉ thay nội dung — dựng lại là mất luôn các
        // thành phần đã đăng ký, và một quảng cáo phải nối lại từ đầu.
        if installedAd === ad, let host, let adContext {
            host.rootView = content(adContext)
            return
        }

        tearDown()

        let canvas = NativeAdCanvas()
        canvas.translatesAutoresizingMaskIntoConstraints = false
        view.addSubview(canvas)
        NSLayoutConstraint.activate([
            canvas.topAnchor.constraint(equalTo: view.topAnchor),
            canvas.bottomAnchor.constraint(equalTo: view.bottomAnchor),
            canvas.leadingAnchor.constraint(equalTo: view.leadingAnchor),
            canvas.trailingAnchor.constraint(equalTo: view.trailingAnchor),
        ])

        let adContext = NativeAdContext(ad: ad)
        adContext.adView = canvas
        canvas.adContext = adContext

        let host = UIHostingController(rootView: content(adContext))
        host.sizingOptions = [.intrinsicContentSize]
        host.view.backgroundColor = .clear
        host.view.translatesAutoresizingMaskIntoConstraints = false
        addChild(host)
        canvas.addSubview(host.view)
        NSLayoutConstraint.activate([
            host.view.topAnchor.constraint(equalTo: canvas.topAnchor),
            host.view.bottomAnchor.constraint(equalTo: canvas.bottomAnchor),
            host.view.leadingAnchor.constraint(equalTo: canvas.leadingAnchor),
            host.view.trailingAnchor.constraint(equalTo: canvas.trailingAnchor),
        ])
        host.didMove(toParent: self)

        self.adView = canvas
        self.host = host
        self.adContext = adContext
        self.installedAd = ad
    }

    /// Chiều cao mà bố cục cần ở bề rộng này.
    ///
    /// Chiều cao đề nghị phải là "bao nhiêu cũng được" chứ không phải 0: đề
    /// nghị 0 thì SwiftUI trả lại đúng 0, và ô quảng cáo dựng ra không cao hơn
    /// một sợi chỉ.
    func fittingSize(width: CGFloat) -> CGSize? {
        guard let host else { return nil }
        let size = host.sizeThatFits(in: CGSize(width: width, height: .greatestFiniteMagnitude))
        return CGSize(width: width, height: max(size.height, 0))
    }

    private func tearDown() {
        host?.willMove(toParent: nil)
        host?.view.removeFromSuperview()
        host?.removeFromParent()
        adView?.removeFromSuperview()
        host = nil
        adView = nil
        adContext = nil
        installedAd = nil
    }
}

/// `NativeAdView` biết lúc nào bố cục đã dựng xong.
///
/// Các thành phần SwiftUI xuất hiện dần qua vài vòng bố cục; nối quảng cáo ở
/// cuối mỗi vòng là chỗ chắc chắn nhất để mọi thành phần đã có mặt.
private final class NativeAdCanvas: GoogleMobileAds.NativeAdView {

    var adContext: NativeAdContext?

    override func layoutSubviews() {
        super.layoutSubviews()
        MainActor.assumeIsolated { adContext?.commit() }
    }
}
