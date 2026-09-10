import UIKit
import GoogleMobileAds

/// Quảng cáo xen kẽ có thưởng — xen giữa hai màn hình như interstitial nhưng
/// có phần thưởng như rewarded, và bắt buộc báo trước cho người dùng.
@MainActor
public final class RewardedInterstitialCenter: FullScreenAdCenter<RewardedInterstitialAd> {

    init() {
        super.init(
            format: .rewardedInterstitial,
            loadAd: { unitId, request in
                try await RewardedInterstitialAd.load(with: unitId, request: request)
            },
            attachPaidHandler: { ad, unitId, slot in
                ad.paidEventHandler = { value in
                    reportPaidEvent(value, format: .rewardedInterstitial, slot: slot, unitId: unitId)
                }
            }
        )
    }

    @discardableResult
    public func show(
        slot: AdSlot = .default,
        from viewController: UIViewController? = nil
    ) async -> AdRewardResult {

        let box = RewardBox()

        let result = await run(slot: slot, pacing: nil, from: viewController) { ad, presenter, delegate in
            await delegate.present(ad, from: presenter) { controller in
                ad.present(from: controller) {
                    box.reward = (Int(truncating: ad.adReward.amount), ad.adReward.type)
                }
            }
        }

        return finalize(result, box: box, slot: slot, format: .rewardedInterstitial)
    }
}
