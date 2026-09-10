import SwiftUI
import GoogleMobileAds
import GSXCore

/// Ô quảng cáo native.
///
/// Hai cách dùng. Mẫu dựng sẵn, chỉnh giao diện bằng `NativeAdTheme`:
///
/// ```swift
/// NativeAdSlot(slot: "feed", style: .medium)
/// ```
///
/// Hoặc tự viết bố cục bằng chính các thành phần SwiftUI của SDK — muốn đặt
/// đâu, to nhỏ thế nào, xen vào giao diện của app ra sao cũng được, mà Google
/// vẫn đếm đúng lượt hiện và lượt bấm:
///
/// ```swift
/// NativeAdSlot(slot: "feed") {
///     VStack(alignment: .leading, spacing: 8) {
///         NativeMedia(aspectRatio: 4 / 3)
///         HStack {
///             NativeIcon(size: 40)
///             NativeHeadline()
///             Spacer()
///             NativeAdBadge()
///         }
///         NativeCallToAction().frame(maxWidth: .infinity, minHeight: 44)
///     }
///     .padding(12)
/// }
/// ```
///
/// Chưa tải xong, tải hỏng, hay người dùng đã mua thì ô này không chiếm chỗ
/// nào — trừ khi truyền `reservedHeight`.
public struct NativeAdSlot<Content: View>: View {

    private let slot: AdSlot
    private let reservedHeight: CGFloat?
    private let content: () -> Content

    @Environment(\.nativeAdTheme) private var theme
    @State private var controller: NativeAdController

    public init(
        slot: AdSlot = .default,
        reservedHeight: CGFloat? = nil,
        @ViewBuilder content: @escaping () -> Content
    ) {
        self.slot = slot
        self.reservedHeight = reservedHeight
        self.content = content
        _controller = State(initialValue: NativeAdController(slot: slot))
    }

    public var body: some View {
        slotContent
            .task(id: readinessKey) {
                if canShow {
                    controller.load()
                } else {
                    controller.clear()
                }
            }
    }

    @ViewBuilder
    private var slotContent: some View {
        if canShow, let ad = controller.ad {
            NativeAdContainer(ad: ad, theme: theme) { content() }
        } else {
            // Ô rỗng vẫn là một View thật, cao 0.
            //
            // Trả về `EmptyView` thì SwiftUI bỏ hẳn nó khỏi cây — và cùng với
            // nó là `.task` gắn ở trên. Ô này gần như luôn dựng *trước* khi SDK
            // khởi động xong, nên "biến mất" ở đây nghĩa là không bao giờ còn
            // ai chạy lại để tải quảng cáo nữa.
            Color.clear.frame(height: canShow ? (reservedHeight ?? 0) : 0)
        }
    }

    /// Đổi khi SDK khởi động xong hoặc khi người dùng mua — cả hai đều là lý do
    /// để hỏi lại xem ô này còn nên tồn tại không.
    private var readinessKey: String {
        "\(AdsKit.shared.isReady)-\(EntitlementCenter.shared.isAdsRemoved)"
    }

    private var canShow: Bool {
        guard let configuration = AdsKit.shared.configuration else { return false }
        return configuration.isEnabled
            && !configuration.ids(for: .native).isEmpty
            && !EntitlementCenter.shared.isAdsRemoved
            && AdsKit.shared.isReady
    }
}

// MARK: - Mẫu dựng sẵn

/// Ba khuôn hay dùng.
public enum NativeAdStyle: Sendable, CaseIterable {
    /// Một hàng gọn: biểu tượng, tiêu đề, nút. Hợp để chèn giữa danh sách.
    case small
    /// Có ảnh, đủ tiêu đề, mô tả và nút. Khuôn dùng nhiều nhất.
    case medium
    /// Ảnh lớn trên cùng — hợp với ô chiếm gần hết màn hình.
    case large

    /// Chiều cao tạm giữ chỗ trong lúc tải, nếu bên gọi muốn giữ.
    public var approximateHeight: CGFloat {
        switch self {
        case .small:  return 76
        case .medium: return 355
        case .large:  return 385
        }
    }
}

public extension NativeAdSlot where Content == NativeAdPresetLayout {

    /// Ô native dùng khuôn dựng sẵn.
    ///
    /// - Parameter reservesSpace: giữ sẵn chỗ trong lúc tải để danh sách không
    ///   giật khi quảng cáo hiện ra.
    init(slot: AdSlot = .default, style: NativeAdStyle = .medium, reservesSpace: Bool = false) {
        self.init(
            slot: slot,
            reservedHeight: reservesSpace ? style.approximateHeight : nil
        ) {
            NativeAdPresetLayout(style: style)
        }
    }
}

/// Bố cục của các khuôn dựng sẵn.
///
/// Viết bằng đúng những thành phần công khai ở trên, nên khuôn riêng của app
/// không bị thiệt gì so với khuôn của SDK — chép file này ra sửa là được.
public struct NativeAdPresetLayout: View {

    @Environment(\.nativeAdTheme) private var theme
    private let style: NativeAdStyle

    public init(style: NativeAdStyle) {
        self.style = style
    }

    public var body: some View {
        layout
            .padding(theme.padding)
            .frame(maxWidth: .infinity, alignment: .leading)
            .background(theme.background)
            .clipShape(RoundedRectangle(cornerRadius: theme.cornerRadius, style: .continuous))
            .overlay {
                if theme.borderWidth > 0 {
                    RoundedRectangle(cornerRadius: theme.cornerRadius, style: .continuous)
                        .strokeBorder(theme.borderColor, lineWidth: theme.borderWidth)
                }
            }
    }

    @ViewBuilder
    private var layout: some View {
        switch style {
        case .small:  small
        case .medium: medium
        case .large:  large
        }
    }

    private var small: some View {
        HStack(spacing: 10) {
            NativeIcon(size: 44)
            VStack(alignment: .leading, spacing: 2) {
                HStack(spacing: 4) {
                    NativeAdBadge()
                    NativeAdvertiser()
                }
                NativeHeadline(lines: 1)
                NativeBody(lines: 1)
            }
            Spacer(minLength: 4)
            NativeCallToAction()
                .frame(width: 92, height: 36)
        }
    }

    private var medium: some View {
        VStack(alignment: .leading, spacing: 8) {
            header
            NativeBody(lines: 2)
            // 1.91:1 là khuôn Google vẫn dùng cho creative native. Giờ ảnh lấp
            // đầy khung nên ép tỉ lệ chỉ cắt bớt mép, không lòi nền ra nữa.
            NativeMedia(aspectRatio: 1.91)
            NativeCallToAction()
                .frame(maxWidth: .infinity, minHeight: 44)
        }
    }

    private var large: some View {
        VStack(alignment: .leading, spacing: 10) {
            NativeMedia(aspectRatio: 1.91)
            header
            NativeBody(lines: 3)
            NativeCallToAction()
                .frame(maxWidth: .infinity, minHeight: 48)
        }
    }

    private var header: some View {
        HStack(alignment: .top, spacing: 10) {
            NativeIcon(size: 44)
            VStack(alignment: .leading, spacing: 2) {
                NativeHeadline(lines: 2)
                HStack(spacing: 4) {
                    NativeAdBadge()
                    NativeAdvertiser()
                    NativeStarRating()
                }
            }
            Spacer(minLength: 0)
        }
    }
}
