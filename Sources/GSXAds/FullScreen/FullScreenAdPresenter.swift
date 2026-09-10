import UIKit
import GoogleMobileAds
import GSXCore

/// Kết quả một lần định hiện quảng cáo toàn màn hình.
public enum AdShowResult: Sendable {
    /// Đã hiện và người dùng đã đóng lại.
    case shown
    /// Không hiện, kèm lý do. Không phải lý do nào cũng là lỗi — xem
    /// `AdError.isFailure`.
    case skipped(AdError)

    public var didShow: Bool {
        if case .shown = self { return true }
        return false
    }
}

/// Kết quả một lần xem quảng cáo có thưởng.
public enum AdRewardResult: Sendable {
    /// Đã xem đủ và nhận thưởng.
    case earned(amount: Int, type: String)
    /// Có hiện nhưng đóng sớm, không có thưởng.
    case dismissed
    case skipped(AdError)

    public var isEarned: Bool {
        if case .earned = self { return true }
        return false
    }
}

/// Cầu nối giữa delegate của GMA và `async/await`.
///
/// Bản UIKit phải dựng một `UIViewController` rỗng 0×0 gắn tạm vào màn hình chỉ
/// để nhận `onAdClosed`, vì tầng quảng cáo báo về bằng cách gọi phương thức
/// trên view controller. Ở đây một `await` là đủ, và không có gì được thêm vào
/// cây view.
@MainActor
final class FullScreenAdPresenter: NSObject, FullScreenContentDelegate {

    /// Quảng cáo đã thật sự lên màn hình chưa. Sau mốc đó thì chờ bao lâu cũng
    /// được — người dùng đang xem.
    private var didPresent = false

    /// Chờ tối đa bấy nhiêu giây cho quảng cáo hiện lên.
    ///
    /// Có vài đường trong GMA gọi `present` mà không báo lại gì cả; không có
    /// phanh này thì bên gọi `await` mãi mãi, và thứ nằm sau nó — một nút back,
    /// một tính năng vừa mở khoá — không bao giờ tới.
    private static let presentationTimeout: TimeInterval = 5

    private var continuation: CheckedContinuation<AdShowResult, Never>?
    private let format: AdType
    private let slot: AdSlot

    init(format: AdType, slot: AdSlot) {
        self.format = format
        self.slot = slot
    }

    /// Hiện quảng cáo và chờ tới lúc nó biến mất.
    ///
    /// `present` được truyền vào chứ không gọi thẳng, vì mỗi định dạng có chữ
    /// ký riêng — loại có thưởng còn kèm closure trả thưởng.
    func present(
        _ ad: FullScreenPresentingAd,
        from viewController: UIViewController,
        present action: (UIViewController) -> Void
    ) async -> AdShowResult {

        ad.fullScreenContentDelegate = self

        return await withCheckedContinuation { continuation in
            self.continuation = continuation
            // Chốt cửa ngay tại đây chứ không đợi `adWillPresentFullScreenContent`:
            // giữa hai mốc đó vẫn còn khe cho một quảng cáo thứ hai chen vào.
            AdsKit.shared.presentation.isPresenting = true
            action(viewController)
            startWatchdog()
        }
    }

    private func startWatchdog() {
        Task { @MainActor [weak self] in
            try? await Task.sleep(nanoseconds: UInt64(Self.presentationTimeout * 1_000_000_000))
            guard let self, !self.didPresent else { return }
            AdsKit.shared.emit(self.format, self.slot, .failed(.timedOut))
            self.finish(.skipped(.timedOut))
        }
    }

    /// Chỉ trả lời một lần. Một lượt hiện có thể vừa báo lỗi vừa báo đóng, và
    /// thứ nằm sau `await` không được phép chạy hai lần.
    private func finish(_ result: AdShowResult) {
        guard let continuation else { return }
        self.continuation = nil

        let state = AdsKit.shared.presentation
        state.isPresenting = false
        state.lastDismissedAt = Date()

        continuation.resume(returning: result)
    }

    // MARK: - FullScreenContentDelegate

    func adWillPresentFullScreenContent(_ ad: FullScreenPresentingAd) {
        didPresent = true
        AdsKit.shared.presentation.isPresenting = true
        AdsKit.shared.emit(format, slot, .opened)
    }

    func adDidDismissFullScreenContent(_ ad: FullScreenPresentingAd) {
        AdsKit.shared.emit(format, slot, .closed)
        finish(.shown)
    }

    func ad(_ ad: FullScreenPresentingAd, didFailToPresentFullScreenContentWithError error: Error) {
        let adError = AdError.google(error.localizedDescription)
        AdsKit.shared.emit(format, slot, .failed(adError))
        finish(.skipped(adError))
    }

    func adDidRecordImpression(_ ad: FullScreenPresentingAd) {
        AdsKit.shared.emit(format, slot, .impression)
    }

    func adDidRecordClick(_ ad: FullScreenPresentingAd) {
        AdsKit.shared.emit(format, slot, .click)
    }
}
