import UIKit
import GoogleMobileAds
import GSXCore

/// Quảng cáo App Open.
///
/// Hai đường khác hẳn nhau, và bản UIKit gộp chung vào một hàm với cờ
/// `displayAOA` nên rất khó đọc:
///
/// - `showOnLaunch()` — lần mở app từ đầu. Màn hình splash đang *đợi* câu trả
///   lời, nên có lớp phủ chờ và có hạn chờ.
/// - `showIfAvailable()` — quay lại app từ nền. Không ai đợi cả, nên chỉ hiện
///   khi đã có sẵn quảng cáo; chưa có thì tải cho lần sau chứ không giữ người
///   dùng lại nhìn màn hình chờ.
@MainActor
public final class AppOpenCenter: FullScreenAdCenter<AppOpenAd> {

    /// Đã hiện quảng cáo mở app trong phiên này chưa. Dùng để lần quay lại đầu
    /// tiên sau khi mở app không hiện thêm một cái nữa ngay sau cái vừa xem.
    private(set) var hasShownThisSession = false

    init() {
        super.init(
            format: .appOpen,
            loadAd: { unitId, request in
                try await AppOpenAd.load(with: unitId, request: request)
            },
            attachPaidHandler: { ad, unitId, slot in
                ad.paidEventHandler = { value in
                    reportPaidEvent(value, format: .appOpen, slot: slot, unitId: unitId)
                }
            }
        )
        expiration = 4 * 3600
    }

    /// Tải sẵn cho lần quay lại app tiếp theo.
    ///
    /// Gọi muộn sau khi app đã mở xong, đừng gọi ngay lúc khởi động: dựng quảng
    /// cáo lúc đó là tranh luồng chính với màn hình đầu tiên, mà cái này là
    /// quảng cáo cho lần *quay lại* chứ không phải lần mở.
    public func prepare() {
        syncExpiration()
        preload(slot: .default)
    }

    /// Quảng cáo cho lần mở app từ đầu — gọi từ màn hình splash.
    ///
    /// Trả lời trong mọi trường hợp, nên splash cứ `await` rồi đi tiếp là đúng.
    @discardableResult
    public func showOnLaunch(from viewController: UIViewController? = nil) async -> AdShowResult {
        syncExpiration()
        let result = await run(slot: .default, pacing: nil, from: viewController) { ad, presenter, delegate in
            await delegate.present(ad, from: presenter) { controller in
                ad.present(from: controller)
            }
        }
        if result.didShow { hasShownThisSession = true }
        return result
    }

    /// Quảng cáo cho lần quay lại app.
    ///
    /// Chỉ hiện khi đã có sẵn: người dùng vừa chuyển về app và đang nhìn vào
    /// nội dung của mình, giữ họ lại sau một màn hình chờ để đi tải quảng cáo
    /// là điều tệ nhất có thể làm ở đúng khoảnh khắc đó.
    @discardableResult
    public func showIfAvailable(from viewController: UIViewController? = nil) async -> AdShowResult {
        syncExpiration()

        guard AdsKit.shared.configuration?.showsAppOpenOnForeground == true else {
            return .skipped(.adsDisabled)
        }
        // Form đồng ý đang mở, hoặc một quảng cáo toàn màn hình khác đang chạy.
        guard !ConsentManager.shared.isPresentingForm else { return .skipped(.alreadyPresenting) }
        guard !AdsKit.shared.presentation.isBusy else { return .skipped(.alreadyPresenting) }

        guard isReady(slot: .default) else {
            preload(slot: .default)
            return .skipped(.alreadyLoading)
        }

        let result = await run(slot: .default, pacing: nil, from: viewController) { ad, presenter, delegate in
            await delegate.present(ad, from: presenter) { controller in
                ad.present(from: controller)
            }
        }
        if result.didShow { hasShownThisSession = true }
        return result
    }

    private func syncExpiration() {
        expiration = AdsKit.shared.configuration?.appOpenExpiration ?? 4 * 3600
    }
}
