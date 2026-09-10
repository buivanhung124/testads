import SwiftUI
import GoogleMobileAds

// Các mảnh của một quảng cáo native, dùng như View SwiftUI bình thường.
//
// Mỗi mảnh tự dựng `UIView` của nó và đăng ký với `NativeAdContext`, nên bố cục
// viết bằng SwiftUI mà Google vẫn đếm đúng lượt hiện và lượt bấm. Mảnh nào
// quảng cáo không có thì tự biến mất — chỉ `headline` và `media` là chắc chắn
// luôn có.
//
// Đặt trong `NativeAdSlot`; ở ngoài thì không có gì để vẽ và chúng trả về rỗng.

/// Tiêu đề. Luôn có trong mọi quảng cáo native.
public struct NativeHeadline: View {
    @Environment(\.nativeAdContext) private var adContext
    @Environment(\.nativeAdTheme) private var theme
    private let lines: Int

    public init(lines: Int = 2) { self.lines = lines }

    public var body: some View {
        if let adContext, let text = adContext.ad.headline, !text.isEmpty {
            NativeLabelView(
                text: text, role: .headline,
                font: theme.headlineFont, color: UIColor(theme.headlineColor),
                lines: lines, adContext: adContext
            )
            .fixedSize(horizontal: false, vertical: true)
        }
    }
}

/// Mô tả. Có thể không có.
public struct NativeBody: View {
    @Environment(\.nativeAdContext) private var adContext
    @Environment(\.nativeAdTheme) private var theme
    private let lines: Int

    public init(lines: Int = 2) { self.lines = lines }

    public var body: some View {
        if let adContext, let text = adContext.ad.body, !text.isEmpty {
            NativeLabelView(
                text: text, role: .body,
                font: theme.bodyFont, color: UIColor(theme.bodyColor),
                lines: lines, adContext: adContext
            )
            .fixedSize(horizontal: false, vertical: true)
        }
    }
}

/// Tên nhà quảng cáo.
public struct NativeAdvertiser: View {
    @Environment(\.nativeAdContext) private var adContext
    @Environment(\.nativeAdTheme) private var theme

    public init() {}

    public var body: some View {
        if let adContext, let text = adContext.ad.advertiser, !text.isEmpty {
            NativeLabelView(
                text: text, role: .advertiser,
                font: theme.advertiserFont, color: UIColor(theme.advertiserColor),
                lines: 1, adContext: adContext
            )
        }
    }
}

/// Tên cửa hàng ("App Store", "Google Play").
public struct NativeStore: View {
    @Environment(\.nativeAdContext) private var adContext
    @Environment(\.nativeAdTheme) private var theme

    public init() {}

    public var body: some View {
        if let adContext, let text = adContext.ad.store, !text.isEmpty {
            NativeLabelView(
                text: text, role: .store,
                font: theme.advertiserFont, color: UIColor(theme.advertiserColor),
                lines: 1, adContext: adContext
            )
        }
    }
}

/// Giá.
public struct NativePrice: View {
    @Environment(\.nativeAdContext) private var adContext
    @Environment(\.nativeAdTheme) private var theme

    public init() {}

    public var body: some View {
        if let adContext, let text = adContext.ad.price, !text.isEmpty {
            NativeLabelView(
                text: text, role: .price,
                font: theme.advertiserFont, color: UIColor(theme.advertiserColor),
                lines: 1, adContext: adContext
            )
        }
    }
}

/// Điểm sao, vẽ bằng ký tự nên không cần ảnh kèm theo.
public struct NativeStarRating: View {
    @Environment(\.nativeAdContext) private var adContext
    @Environment(\.nativeAdTheme) private var theme

    public init() {}

    public var body: some View {
        if let adContext, let rating = adContext.ad.starRating?.doubleValue, rating > 0 {
            NativeLabelView(
                text: Self.stars(rating), role: .starRating,
                font: theme.advertiserFont, color: UIColor(.orange),
                lines: 1, adContext: adContext
            )
            .accessibilityLabel(Text(String(format: "%.1f/5", rating)))
        }
    }

    private static func stars(_ rating: Double) -> String {
        let full = Int(rating.rounded(.down))
        let hasHalf = rating - Double(full) >= 0.5
        let empty = 5 - full - (hasHalf ? 1 : 0)
        return String(repeating: "★", count: max(0, full))
            + (hasHalf ? "⯪" : "")
            + String(repeating: "☆", count: max(0, empty))
    }
}

/// Biểu tượng ứng dụng được quảng cáo.
public struct NativeIcon: View {
    @Environment(\.nativeAdContext) private var adContext
    @Environment(\.nativeAdTheme) private var theme
    private let size: CGFloat

    public init(size: CGFloat = 48) { self.size = size }

    public var body: some View {
        if let adContext, let image = adContext.ad.icon?.image {
            NativeIconView(image: image, cornerRadius: theme.iconCornerRadius, adContext: adContext)
                .frame(width: size, height: size)
        }
    }
}

/// Vùng ảnh/video chính. Luôn có, và bắt buộc phải hiện với quảng cáo có video.
public struct NativeMedia: View {
    @Environment(\.nativeAdContext) private var adContext
    @Environment(\.nativeAdTheme) private var theme

    /// Bỏ trống thì lấy tỷ lệ thật của quảng cáo — ảnh không bị cắt hay kéo méo.
    private let aspectRatio: CGFloat?
    private let contentMode: ContentMode

    public init(aspectRatio: CGFloat? = nil, contentMode: ContentMode = .fit) {
        self.aspectRatio = aspectRatio
        self.contentMode = contentMode
    }

    public var body: some View {
        if let adContext {
            // Tỉ lệ do một `Color.clear` mềm giữ, `MediaView` phủ lên trên.
            //
            // Đặt `.aspectRatio` thẳng lên `MediaView` thì kích thước tự nhiên
            // của ảnh thắng — một logo vuông kéo cả khung thành vuông, nằm lọt
            // thỏm giữa ô rộng. Bọc thế này thì khung do bố cục quyết định, còn
            // ảnh chỉ việc lấp đầy nó.
            Color.clear
                .aspectRatio(resolvedRatio(adContext), contentMode: contentMode)
                .overlay {
                    // Ép lấp đầy: `MediaView` có kích thước tự nhiên theo ảnh
                    // và sẽ co về đúng cỡ đó nếu không bị buộc.
                    NativeMediaContentView(adContext: adContext)
                        .frame(maxWidth: .infinity, maxHeight: .infinity)
                }
                .clipShape(RoundedRectangle(cornerRadius: theme.mediaCornerRadius, style: .continuous))
        }
    }

    /// Tỉ lệ khung.
    ///
    /// Mặc định là tỉ lệ thật của quảng cáo, vì khung khớp ảnh thì ảnh lấp đầy
    /// khung — ép 16:9 lên một creative vuông chỉ tổ lòi hai mảng nền ra hai
    /// bên. Vẫn kẹp lại hai đầu: một creative rất cao hoặc rất dẹt không được
    /// phép quyết định chiều cao của cả ô quảng cáo.
    private func resolvedRatio(_ adContext: NativeAdContext) -> CGFloat {
        if let aspectRatio, aspectRatio > 0 { return aspectRatio }
        let natural = adContext.ad.mediaContent.aspectRatio
        guard natural > 0 else { return 16.0 / 9.0 }
        return min(max(natural, 0.9), 2.0)
    }
}

/// Nút kêu gọi hành động.
///
/// Cố ý **không** nhận `action`: cú bấm thuộc về Google Mobile Ads, và tự xử lý
/// nó là làm hỏng việc đếm bấm — cũng là vi phạm chính sách. Đặt nút ở đâu và
/// to nhỏ thế nào thì tuỳ bố cục.
public struct NativeCallToAction: View {
    @Environment(\.nativeAdContext) private var adContext
    @Environment(\.nativeAdTheme) private var theme

    public init() {}

    public var body: some View {
        if let adContext, let title = adContext.ad.callToAction, !title.isEmpty {
            NativeCTAView(
                title: title,
                font: theme.ctaFont,
                background: UIColor(theme.ctaBackground),
                foreground: UIColor(theme.ctaForeground),
                cornerRadius: theme.ctaCornerRadius,
                adContext: adContext
            )
        }
    }
}

/// Nhãn "Ad".
///
/// Google bắt buộc quảng cáo native phải được đánh dấu rõ ràng. Không phải một
/// thành phần của quảng cáo nên không đăng ký với `NativeAdView` — chỉ là chữ.
public struct NativeAdBadge: View {
    @Environment(\.nativeAdTheme) private var theme

    public init() {}

    public var body: some View {
        Text(theme.badgeText)
            .font(.system(size: 10, weight: .bold))
            .foregroundStyle(theme.badgeForeground)
            .padding(.horizontal, 4)
            .padding(.vertical, 1)
            .background(theme.badgeBackground, in: RoundedRectangle(cornerRadius: 3, style: .continuous))
    }
}

// MARK: - Cầu nối UIKit

private struct NativeLabelView: UIViewRepresentable {

    let text: String
    let role: NativeAssetRole
    let font: UIFont
    let color: UIColor
    let lines: Int
    let adContext: NativeAdContext

    func makeUIView(context: Context) -> UILabel {
        let label = UILabel()
        label.numberOfLines = lines
        label.lineBreakMode = .byTruncatingTail
        label.font = font
        label.textColor = color
        label.text = text
        label.adjustsFontForContentSizeCategory = true
        label.setContentCompressionResistancePriority(.defaultLow, for: .horizontal)
        adContext.register(label, as: role)
        return label
    }

    func updateUIView(_ label: UILabel, context: Context) {
        label.text = text
        label.font = font
        label.textColor = color
        label.numberOfLines = lines
    }

    /// Chiều cao thật của chữ ở bề rộng SwiftUI đề nghị — không có nó thì nhãn
    /// hai dòng vẫn chỉ được cấp chỗ cho một.
    func sizeThatFits(_ proposal: ProposedViewSize, uiView: UILabel, context: Context) -> CGSize? {
        let width = proposal.width ?? UIView.layoutFittingCompressedSize.width
        let fitted = uiView.sizeThatFits(CGSize(width: width, height: .greatestFiniteMagnitude))
        return CGSize(width: min(width, max(fitted.width, 0)), height: fitted.height)
    }
}

private struct NativeIconView: UIViewRepresentable {

    let image: UIImage
    let cornerRadius: CGFloat
    let adContext: NativeAdContext

    func makeUIView(context: Context) -> UIImageView {
        let view = UIImageView(image: image)
        view.contentMode = .scaleAspectFill
        view.clipsToBounds = true
        view.layer.cornerRadius = cornerRadius
        view.setContentHuggingPriority(.defaultLow, for: .horizontal)
        adContext.register(view, as: .icon)
        return view
    }

    func updateUIView(_ view: UIImageView, context: Context) {
        view.image = image
        view.layer.cornerRadius = cornerRadius
    }

    func sizeThatFits(_ proposal: ProposedViewSize, uiView: UIImageView, context: Context) -> CGSize? {
        CGSize(width: proposal.width ?? 48, height: proposal.height ?? 48)
    }
}

private struct NativeMediaContentView: UIViewRepresentable {

    let adContext: NativeAdContext

    func makeUIView(context: Context) -> MediaView {
        let view = MediaView()
        view.clipsToBounds = true
        view.mediaContent = adContext.ad.mediaContent
        // Đặt *sau* khi gán nội dung: gán `mediaContent` kéo theo cách vẽ riêng
        // của nó, và một `contentMode` đặt trước đó không còn hiệu lực.
        view.contentMode = .scaleAspectFill
        adContext.register(view, as: .media)
        return view
    }

    func updateUIView(_ view: MediaView, context: Context) {
        view.mediaContent = adContext.ad.mediaContent
        view.contentMode = .scaleAspectFill
    }

    /// Lấp trọn khung được cấp, không đòi kích thước riêng.
    func sizeThatFits(_ proposal: ProposedViewSize, uiView: MediaView, context: Context) -> CGSize? {
        proposal.replacingUnspecifiedDimensions()
    }
}

private struct NativeCTAView: UIViewRepresentable {

    let title: String
    let font: UIFont
    let background: UIColor
    let foreground: UIColor
    let cornerRadius: CGFloat
    let adContext: NativeAdContext

    func makeUIView(context: Context) -> UIButton {
        let button = UIButton(type: .custom)
        apply(to: button)
        // Bắt buộc: Google Mobile Ads nhận cú bấm ở lớp trên. Nút mà tự nhận
        // touch thì cú bấm không tới được quảng cáo.
        button.isUserInteractionEnabled = false
        adContext.register(button, as: .callToAction)
        return button
    }

    func updateUIView(_ button: UIButton, context: Context) {
        apply(to: button)
    }

    private func apply(to button: UIButton) {
        button.setTitle(title, for: .normal)
        button.setTitleColor(foreground, for: .normal)
        button.titleLabel?.font = font
        button.titleLabel?.adjustsFontForContentSizeCategory = true
        button.titleLabel?.lineBreakMode = .byTruncatingTail
        button.backgroundColor = background
        button.layer.cornerRadius = cornerRadius
        button.layer.masksToBounds = true
    }

    /// Rộng theo chỗ được cấp, nhưng cao theo chữ.
    ///
    /// Nhận cả chiều cao đề nghị thì `VStack` coi nút là thứ co giãn được và
    /// dồn hết chỗ thừa vào nó — nút "Cài đặt" cao bằng nửa ô quảng cáo. Muốn
    /// cao hơn thì bên gọi tự `.frame(height:)`, và frame ép luôn thắng.
    func sizeThatFits(_ proposal: ProposedViewSize, uiView: UIButton, context: Context) -> CGSize? {
        let intrinsic = uiView.intrinsicContentSize
        return CGSize(
            width: proposal.width ?? (intrinsic.width + 32),
            height: max(44, intrinsic.height + 16)
        )
    }
}
