import UIKit
import GoogleMobileAds

/// Quảng cáo xen kẽ.
///
/// ```swift
/// // Chặn một nút back: quảng cáo đóng rồi mới đi tiếp, mà không có quảng cáo
/// // thì đi tiếp luôn — không có đường nào không trả lời.
/// await AdsKit.shared.interstitial.show(slot: .exit)
/// dismiss()
/// ```
@MainActor
public final class InterstitialCenter: FullScreenAdCenter<InterstitialAd> {

    init() {
        super.init(
            format: .interstitial,
            loadAd: { unitId, request in
                try await InterstitialAd.load(with: unitId, request: request)
            },
            attachPaidHandler: { ad, unitId, slot in
                ad.paidEventHandler = { value in
                    reportPaidEvent(value, format: .interstitial, slot: slot, unitId: unitId)
                }
            }
        )
    }

    /// Hiện quảng cáo rồi trả lời.
    ///
    /// - Parameters:
    ///   - slot: vị trí, để đếm nhịp riêng và giữ kho riêng.
    ///   - pacing: bỏ trống thì lấy `configuration.interstitialPacing`.
    ///     Truyền `.everyTime` khi muốn lần nào cũng hiện.
    ///   - viewController: bỏ trống thì SDK tự tìm màn hình trên cùng.
    @discardableResult
    public func show(
        slot: AdSlot = .default,
        pacing: InterstitialPacing? = nil,
        from viewController: UIViewController? = nil
    ) async -> AdShowResult {

        let effective = pacing ?? AdsKit.shared.configuration?.interstitialPacing ?? .everyTime

        return await run(slot: slot, pacing: effective, from: viewController) { ad, presenter, delegate in
            await delegate.present(ad, from: presenter) { controller in
                ad.present(from: controller)
            }
        }
    }
}
