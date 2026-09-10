import UIKit
import GoogleMobileAds
import GSXCore

/// View controller mang một `BannerView`.
///
/// Có mặt vì `BannerView.rootViewController` phải là một view controller đang
/// hiển thị — GMA dùng nó để mở màn hình quảng cáo khi có người bấm. SwiftUI
/// không đưa ra cái nào, nên `UIViewControllerRepresentable` dựng đúng một cái
/// vừa vặn quanh banner và đó cũng là root của chính nó.
@MainActor
final class BannerHostController: UIViewController, BannerViewDelegate {

    /// Chiều cao thật của quảng cáo đang hiện — 0 khi không có gì.
    var onHeightChange: ((CGFloat) -> Void)?

    private var bannerView: BannerView?
    private var slot: AdSlot = .default
    private var collapsible: CollapsibleBannerMode = .none
    private var size: BannerSize = .adaptive
    private var availableWidth: CGFloat = 0
    private var loadedWidth: CGFloat = 0
    private var loadedUnitId = ""
    private var isLoading = false
    private var tierIndex = 0

    override func viewDidLoad() {
        super.viewDidLoad()
        view.backgroundColor = .clear
        view.clipsToBounds = true
    }

    // MARK: - Cấu hình

    func update(slot: AdSlot, collapsible: CollapsibleBannerMode, size: BannerSize, width: CGFloat) {
        self.slot = slot
        self.collapsible = collapsible
        self.size = size

        guard width > 0 else { return }
        let widthChanged = abs(width - loadedWidth) > 1
        availableWidth = width

        // Xoay máy hoặc đổi bề rộng cửa sổ (Split View trên iPad) thì kích cỡ
        // thích hợp cũng đổi, nên phải hỏi lại quảng cáo mới. Cùng bề rộng thì
        // không đụng vào — mỗi lần tải lại là một lượt hiện bị mất.
        if bannerView != nil, widthChanged {
            reload()
        } else if bannerView == nil, !isLoading {
            load()
        }
    }

    func reload() {
        tearDown()
        load()
    }

    // MARK: - Tải

    private func load() {
        if let error = AdGate.check(.banner) {
            AdsKit.shared.emit(.banner, slot, .failed(error))
            collapse()
            return
        }
        guard availableWidth > 0, !isLoading else { return }

        let ids = AdsKit.shared.configuration?.ids(for: .banner) ?? []
        guard !ids.isEmpty else { return collapse() }

        isLoading = true
        loadedWidth = availableWidth
        tierIndex = 0
        request(ids: ids, index: 0)
    }

    /// Tầng dự phòng cho banner.
    ///
    /// Banner báo về bằng delegate chứ không phải `async`, nên tầng dự phòng ở
    /// đây là gọi đệ quy sang id kế tiếp trong `didFailToReceiveAdWithError`,
    /// chứ không dùng được `AdWaterfall`. Kết quả thì như nhau: hết id mới chịu
    /// thua.
    private func request(ids: [String], index: Int) {
        guard index < ids.count else {
            isLoading = false
            collapse()
            return
        }

        tierIndex = index
        let unitId = ids[index]
        loadedUnitId = unitId
        // Chụp lại tên vị trí ngay đây: callback doanh thu của GMA không hứa
        // chạy trên luồng chính, nên không đọc thuộc tính của controller trong đó.
        let currentSlot = slot

        let adSize = adSize(for: availableWidth)
        let banner = BannerView(adSize: adSize)
        banner.adUnitID = unitId
        banner.rootViewController = self
        banner.delegate = self
        // Gắn ngay lúc dựng chứ không đợi `bannerViewDidReceiveAd`: banner co
        // lại được có thể bắn sự kiện doanh thu trước lượt delegate đó, gắn
        // muộn là mất lượt ghi đầu tiên.
        banner.paidEventHandler = { value in
            reportPaidEvent(value, format: .banner, slot: currentSlot, unitId: unitId)
        }

        attach(banner, height: adSize.size.height)
        bannerView = banner

        banner.load(makeRequest(for: adSize))
    }

    private func makeRequest(for adSize: AdSize) -> Request {
        let request = AdsKit.shared.makeRequest()
        // Quảng cáo co lại được chỉ phục vụ cho cỡ *anchored adaptive*. Hỏi kèm
        // cỡ cố định 728×90 thì cái trả về là một banner vẽ ra khoảng trống —
        // đúng lỗi đã gặp trên iPad 13" ở bản UIKit.
        guard collapsible != .none, size == .adaptive, !usesLeaderboard(width: availableWidth) else { return request }
        let extras = Extras()
        extras.additionalParameters = ["collapsible": collapsible.rawValue]
        request.register(extras)
        return request
    }

    // MARK: - Kích cỡ

    /// Leaderboard ở bề rộng máy tính bảng, còn lại là anchored adaptive.
    ///
    /// Đo theo bề rộng *cửa sổ* chứ không theo loại máy: một chiếc iPad trong
    /// Split View hẹp là một cột hình dáng như điện thoại, và một banner 728pt
    /// trong đó sẽ bị chính khung chứa cắt mất.
    func adSize(for width: CGFloat) -> AdSize {
        guard size == .adaptive else { return AdSizeBanner }
        guard !usesLeaderboard(width: width) else { return AdSizeLeaderboard }
        return largeAnchoredAdaptiveBanner(width: width)
    }

    private func usesLeaderboard(width: CGFloat) -> Bool {
        width >= AdSizeLeaderboard.size.width
    }

    // MARK: - Bố cục

    private func attach(_ banner: BannerView, height: CGFloat) {
        bannerView?.removeFromSuperview()
        banner.translatesAutoresizingMaskIntoConstraints = false
        view.addSubview(banner)
        NSLayoutConstraint.activate([
            banner.topAnchor.constraint(equalTo: view.topAnchor),
            banner.centerXAnchor.constraint(equalTo: view.centerXAnchor),
            banner.widthAnchor.constraint(equalToConstant: banner.adSize.size.width),
            banner.heightAnchor.constraint(equalToConstant: height),
        ])
    }

    private func tearDown() {
        bannerView?.removeFromSuperview()
        bannerView = nil
        isLoading = false
    }

    private func collapse() {
        tearDown()
        onHeightChange?(0)
    }

    // MARK: - BannerViewDelegate

    func bannerViewDidReceiveAd(_ bannerView: BannerView) {
        isLoading = false
        onHeightChange?(bannerView.adSize.size.height)
        AdsKit.shared.emit(.banner, slot, .loaded)
    }

    func bannerView(_ bannerView: BannerView, didFailToReceiveAdWithError error: Error) {
        AdsKit.shared.emit(.banner, slot, .failed(.google(error.localizedDescription)))
        let ids = AdsKit.shared.configuration?.ids(for: .banner) ?? []
        request(ids: ids, index: tierIndex + 1)
    }

    func bannerViewDidRecordImpression(_ bannerView: BannerView) {
        AdsKit.shared.emit(.banner, slot, .impression)
    }

    func bannerViewDidRecordClick(_ bannerView: BannerView) {
        AdsKit.shared.emit(.banner, slot, .click)
    }

    func bannerViewWillPresentScreen(_ bannerView: BannerView) {
        AdsKit.shared.emit(.banner, slot, .opened)
    }

    func bannerViewDidDismissScreen(_ bannerView: BannerView) {
        AdsKit.shared.emit(.banner, slot, .closed)
    }
}
