import SwiftUI

/// Giao diện của các mẫu native dựng sẵn.
///
/// Đủ để một ô quảng cáo trông như thuộc về app mà không phải tự viết lại bố
/// cục. Muốn đi xa hơn thì dùng `NativeAdSlot` với nội dung tự viết.
public struct NativeAdTheme: Sendable {

    public var background: Color
    public var cornerRadius: CGFloat
    public var borderColor: Color
    public var borderWidth: CGFloat
    public var padding: CGFloat

    public var headlineFont: UIFont
    public var headlineColor: Color

    public var bodyFont: UIFont
    public var bodyColor: Color

    public var advertiserFont: UIFont
    public var advertiserColor: Color

    public var ctaFont: UIFont
    public var ctaBackground: Color
    public var ctaForeground: Color
    public var ctaCornerRadius: CGFloat

    /// Nhãn "Ad". Google bắt buộc phải có, và phải đọc được.
    public var badgeText: String
    public var badgeBackground: Color
    public var badgeForeground: Color

    public var iconCornerRadius: CGFloat
    public var mediaCornerRadius: CGFloat

    public init(
        background: Color = Color(uiColor: .secondarySystemBackground),
        cornerRadius: CGFloat = 12,
        borderColor: Color = .clear,
        borderWidth: CGFloat = 0,
        padding: CGFloat = 12,
        headlineFont: UIFont = .preferredFont(forTextStyle: .headline),
        headlineColor: Color = .primary,
        bodyFont: UIFont = .preferredFont(forTextStyle: .footnote),
        bodyColor: Color = .secondary,
        advertiserFont: UIFont = .preferredFont(forTextStyle: .caption2),
        advertiserColor: Color = .secondary,
        ctaFont: UIFont = UIFontMetrics(forTextStyle: .subheadline)
            .scaledFont(for: .systemFont(ofSize: 15, weight: .semibold)),
        ctaBackground: Color = .accentColor,
        ctaForeground: Color = .white,
        ctaCornerRadius: CGFloat = 10,
        badgeText: String = "Ad",
        badgeBackground: Color = .yellow,
        badgeForeground: Color = .black,
        iconCornerRadius: CGFloat = 10,
        mediaCornerRadius: CGFloat = 10
    ) {
        self.background = background
        self.cornerRadius = cornerRadius
        self.borderColor = borderColor
        self.borderWidth = borderWidth
        self.padding = padding
        self.headlineFont = headlineFont
        self.headlineColor = headlineColor
        self.bodyFont = bodyFont
        self.bodyColor = bodyColor
        self.advertiserFont = advertiserFont
        self.advertiserColor = advertiserColor
        self.ctaFont = ctaFont
        self.ctaBackground = ctaBackground
        self.ctaForeground = ctaForeground
        self.ctaCornerRadius = ctaCornerRadius
        self.badgeText = badgeText
        self.badgeBackground = badgeBackground
        self.badgeForeground = badgeForeground
        self.iconCornerRadius = iconCornerRadius
        self.mediaCornerRadius = mediaCornerRadius
    }
}
