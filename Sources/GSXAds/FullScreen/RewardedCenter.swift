import UIKit
import GoogleMobileAds

/// Quảng cáo có thưởng.
///
/// ```swift
/// if await AdsKit.shared.rewarded.show(slot: "hint").isEarned {
///     giveHint()
/// }
/// ```
@MainActor
public final class RewardedCenter: FullScreenAdCenter<RewardedAd> {

    init() {
        super.init(
            format: .rewarded,
            loadAd: { unitId, request in
                try await RewardedAd.load(with: unitId, request: request)
            },
            attachPaidHandler: { ad, unitId, slot in
                ad.paidEventHandler = { value in
                    reportPaidEvent(value, format: .rewarded, slot: slot, unitId: unitId)
                }
            }
        )
    }

    /// Hiện và chờ tới lúc biết người dùng có nhận được thưởng hay không.
    ///
    /// Không nhịp: quảng cáo có thưởng là thứ người dùng chủ động đổi lấy một
    /// thứ gì đó, nên "chưa tới lượt" ở đây là vô nghĩa.
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

        return finalize(result, box: box, slot: slot, format: .rewarded)
    }
}

/// Giữ phần thưởng lại giúp: nó tới qua closure của GMA chứ không qua delegate,
/// nên phải có chỗ đặt xuống trước khi lượt hiện kết thúc.
@MainActor
final class RewardBox {
    var reward: (amount: Int, type: String)?
}

@MainActor
extension FullScreenAdCenter {

    func finalize(_ result: AdShowResult, box: RewardBox, slot: AdSlot, format: AdType) -> AdRewardResult {
        switch result {
        case .skipped(let error):
            return .skipped(error)
        case .shown:
            guard let reward = box.reward else { return .dismissed }
            AdsKit.shared.emit(format, slot, .rewarded(amount: reward.amount, type: reward.type))
            return .earned(amount: reward.amount, type: reward.type)
        }
    }
}
