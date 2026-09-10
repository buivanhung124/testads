import UIKit
import Observation
import GoogleMobileAds
import GSXCore

/// Tải và giữ một quảng cáo native cho một vị trí.
///
/// Tách khỏi phần hiển thị để một quảng cáo tải xong không bị mất khi SwiftUI
/// dựng lại View — và để màn hình nào muốn tải sẵn từ trước cũng làm được.
@MainActor
@Observable
public final class NativeAdController {

    public private(set) var ad: NativeAd?
    public private(set) var isLoading = false
    public private(set) var lastError: AdError?

    public let slot: AdSlot

    /// Góc đặt biểu tượng AdChoices. Google chèn nó vào, đây chỉ chọn góc.
    public var adChoicesPosition: AdChoicesPosition = .topRightCorner

    private var task: Task<Void, Never>?

    public init(slot: AdSlot = .default) {
        self.slot = slot
    }

    public var isReady: Bool { ad != nil }

    /// Tải, trừ khi đang tải hoặc đã có sẵn.
    public func load() {
        guard ad == nil, task == nil else { return }

        if let error = AdGate.check(.native) {
            lastError = error
            AdsKit.shared.emit(.native, slot, .failed(error))
            return
        }

        let ids = AdsKit.shared.configuration?.ids(for: .native) ?? []
        isLoading = true

        task = Task { @MainActor [weak self] in
            guard let self else { return }
            defer {
                self.task = nil
                self.isLoading = false
            }
            do {
                let loaded = try await AdWaterfall.load(ids: ids, format: .native) { unitId in
                    try await NativeAdRequest(slot: self.slot, adChoices: self.adChoicesPosition)
                        .load(unitId: unitId)
                }
                guard !Task.isCancelled else { return }

                // Trên native, sự kiện doanh thu nằm trên chính quảng cáo chứ
                // không trên view — thiếu chỗ gắn này thì doanh thu native
                // không được ghi nhận ở đâu cả.
                let unitId = loaded.unitId
                let currentSlot = self.slot
                loaded.ad.paidEventHandler = { value in
                    reportPaidEvent(value, format: .native, slot: currentSlot, unitId: unitId)
                }

                self.ad = loaded.ad
                self.lastError = nil
                AdsKit.shared.emit(.native, self.slot, .loaded)
            } catch {
                let adError = (error as? AdError) ?? .google(error.localizedDescription)
                self.lastError = adError
                AdsKit.shared.emit(.native, self.slot, .failed(adError))
            }
        }
    }

    /// Bỏ quảng cáo đang giữ và tải cái mới.
    public func reload() {
        task?.cancel()
        task = nil
        ad = nil
        load()
    }

    /// Bỏ quảng cáo đang giữ — gọi khi người dùng vừa mua.
    public func clear() {
        task?.cancel()
        task = nil
        ad = nil
        isLoading = false
    }
}

/// Một lần gọi `AdLoader`, bọc lại thành `async`.
///
/// Sinh ra rồi bỏ đi sau mỗi lần tải: `AdLoader` giữ delegate ở dạng `weak`,
/// nên đối tượng này phải tự giữ chính nó sống tới lúc có câu trả lời —
/// `retained` là chỗ làm việc đó.
@MainActor
private final class NativeAdRequest: NSObject, NativeAdLoaderDelegate {

    private var continuation: CheckedContinuation<NativeAd, Error>?
    private var loader: AdLoader?
    private var retained: NativeAdRequest?
    private let slot: AdSlot
    private let adChoices: AdChoicesPosition

    init(slot: AdSlot, adChoices: AdChoicesPosition) {
        self.slot = slot
        self.adChoices = adChoices
    }

    func load(unitId: String) async throws -> NativeAd {
        try await withCheckedThrowingContinuation { continuation in
            self.continuation = continuation
            self.retained = self

            let viewOptions = NativeAdViewAdOptions()
            viewOptions.preferredAdChoicesPosition = adChoices

            // Video native mặc định tắt tiếng: một quảng cáo tự phát ra tiếng
            // giữa lúc người dùng đang đọc là lý do gỡ app.
            let videoOptions = VideoOptions()
            videoOptions.shouldStartMuted = true

            let loader = AdLoader(
                adUnitID: unitId,
                rootViewController: TopViewController.find(),
                adTypes: [.native],
                options: [viewOptions, videoOptions]
            )
            loader.delegate = self
            self.loader = loader
            loader.load(AdsKit.shared.makeRequest())
        }
    }

    private func finish(_ result: Result<NativeAd, Error>) {
        guard let continuation else { return }
        self.continuation = nil
        self.loader = nil
        defer { retained = nil }
        continuation.resume(with: result)
    }

    func adLoader(_ adLoader: AdLoader, didReceive nativeAd: NativeAd) {
        finish(.success(nativeAd))
    }

    func adLoader(_ adLoader: AdLoader, didFailToReceiveAdWithError error: Error) {
        finish(.failure(AdError.google(error.localizedDescription)))
    }
}
