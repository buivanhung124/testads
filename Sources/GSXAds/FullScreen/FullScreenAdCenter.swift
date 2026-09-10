import UIKit
import GoogleMobileAds
import GSXCore

/// Phần chung của bốn định dạng toàn màn hình.
///
/// Bản UIKit chép gần như nguyên văn cùng một file bốn lần — interstitial,
/// rewarded, rewarded interstitial, app open — nên một lần sửa lỗi phải nhớ sửa
/// ở bốn chỗ. Ở đây khác nhau đúng ba điểm, và cả ba được truyền vào lúc dựng:
/// hàm tải của GMA, cách gắn `paidEventHandler`, và cách gọi `present`.
///
/// Mỗi vị trí (`slot`) có kho riêng: quảng cáo đã tải, lượt đếm nhịp, và lần
/// tải đang chạy. Nhờ vậy màn hình A và màn hình B không giành nhau một quảng
/// cáo, mà cũng không ai phải tự quản lý gì.
@MainActor
public class FullScreenAdCenter<Ad: AnyObject & FullScreenPresentingAd> {

    struct Cached {
        let ad: Ad
        let unitId: String
        let loadedAt: Date
    }

    let format: AdType

    /// Quảng cáo tải xong nhưng để lâu không dùng thì Google coi là hết hạn.
    /// Một giờ là mức khuyến nghị cho mọi loại trừ App Open.
    var expiration: TimeInterval = 3600

    private let loadAd: (String, Request) async throws -> Ad
    private let attachPaidHandler: (Ad, String, AdSlot) -> Void

    private var cache: [AdSlot: Cached] = [:]
    private var tasks: [AdSlot: Task<Void, Never>] = [:]
    private var lastErrors: [AdSlot: AdError] = [:]
    private var counters: [AdSlot: Int] = [:]

    init(
        format: AdType,
        loadAd: @escaping (String, Request) async throws -> Ad,
        attachPaidHandler: @escaping (Ad, String, AdSlot) -> Void
    ) {
        self.format = format
        self.loadAd = loadAd
        self.attachPaidHandler = attachPaidHandler
    }

    // MARK: - Kho quảng cáo

    /// Có sẵn quảng cáo dùng được ngay không.
    public func isReady(slot: AdSlot = .default) -> Bool {
        validCached(slot) != nil
    }

    /// Tải trước, không hiện — để lúc cần thì có ngay thay vì bắt người dùng
    /// ngồi nhìn màn hình chờ.
    ///
    /// Gọi bao nhiêu lần cũng được: đang tải thì bỏ qua, đã có sẵn thì bỏ qua.
    public func preload(slot: AdSlot = .default) {
        guard AdGate.check(format) == nil else { return }
        guard validCached(slot) == nil, tasks[slot] == nil else { return }
        _ = loadTask(for: slot)
    }

    /// Xoá quảng cáo đang giữ cho một vị trí. Lượt đếm nhịp giữ nguyên.
    public func invalidate(slot: AdSlot = .default) {
        cache[slot] = nil
    }

    /// Xoá sạch mọi vị trí — gọi khi người dùng vừa mua xong.
    public func invalidateAll() {
        cache.removeAll()
        tasks.values.forEach { $0.cancel() }
        tasks.removeAll()
    }

    private func validCached(_ slot: AdSlot) -> Cached? {
        guard let cached = cache[slot] else { return nil }
        guard Date().timeIntervalSince(cached.loadedAt) < expiration else {
            cache[slot] = nil
            return nil
        }
        return cached
    }

    private func loadTask(for slot: AdSlot) -> Task<Void, Never> {
        if let existing = tasks[slot] { return existing }

        let ids = AdsKit.shared.configuration?.ids(for: format) ?? []
        let task = Task { @MainActor [weak self] in
            guard let self else { return }
            defer { self.tasks[slot] = nil }
            do {
                let loaded = try await AdWaterfall.load(ids: ids, format: self.format) { unitId in
                    try await self.loadAd(unitId, AdsKit.shared.makeRequest())
                }
                guard !Task.isCancelled else { return }
                self.attachPaidHandler(loaded.ad, loaded.unitId, slot)
                self.cache[slot] = Cached(ad: loaded.ad, unitId: loaded.unitId, loadedAt: Date())
                self.lastErrors[slot] = nil
                AdsKit.shared.emit(self.format, slot, .loaded)
            } catch {
                let adError = (error as? AdError) ?? .google(error.localizedDescription)
                self.lastErrors[slot] = adError
                AdsKit.shared.emit(self.format, slot, .failed(adError))
            }
        }
        tasks[slot] = task
        return task
    }

    // MARK: - Nhịp hiện

    /// Ghi nhận một lượt và trả lời lượt này có tới lượt hiện không.
    ///
    /// Đếm riêng theo từng vị trí, nên "cứ ba lần thoát màn hình A thì một
    /// quảng cáo" không bị màn hình B đếm hộ.
    func consumePacing(_ pacing: InterstitialPacing, slot: AdSlot) -> Bool {
        let next = (counters[slot] ?? 0) + 1
        counters[slot] = next
        return pacing.shouldShow(at: next)
    }

    /// Đặt lại lượt đếm của một vị trí.
    public func resetPacing(slot: AdSlot = .default) {
        counters[slot] = 0
    }

    // MARK: - Hiện

    /// Toàn bộ đường đi của một lần hiện: kiểm tra điều kiện, lấy quảng cáo
    /// (tải nếu chưa có, kèm lớp phủ chờ và hạn chờ), rồi hiện và đợi đóng.
    ///
    /// Luôn trả lời — dù đúng dù sai. Bên gọi thường đang chặn một nút back
    /// hoặc một tính năng bị khoá, và một đường đi không trả lời là một cánh
    /// cửa không bao giờ mở.
    func run(
        slot: AdSlot,
        pacing: InterstitialPacing?,
        from viewController: UIViewController? = nil,
        present action: @escaping (Ad, UIViewController, FullScreenAdPresenter) async -> AdShowResult
    ) async -> AdShowResult {

        if let error = AdGate.check(format) {
            AdsKit.shared.emit(format, slot, .failed(error))
            return .skipped(error)
        }
        guard let configuration = AdsKit.shared.configuration else { return .skipped(.notConfigured) }

        if let pacing, !consumePacing(pacing, slot: slot) {
            // Chưa tới lượt, nhưng vẫn tải sẵn cho lượt sau.
            preload(slot: slot)
            return .skipped(.pacing)
        }

        let state = AdsKit.shared.presentation
        if let error = state.canStartFullScreen(minimumInterval: configuration.minimumFullScreenInterval) {
            AdsKit.shared.emit(format, slot, .failed(error))
            return .skipped(error)
        }

        // Đã có sẵn thì hiện luôn trong cùng một khung hình. Bản UIKit dò bằng
        // `Timer` mỗi giây, nên ngay cả quảng cáo tải sẵn cũng nằm sau màn hình
        // chờ tới một giây — trên một nút back thì đọc ra là "bấm không ăn".
        var cached = validCached(slot)

        if cached == nil {
            state.loadingText = configuration.loadingText
            state.isLoading = true
            defer { state.isLoading = false }

            let outcome = await waitForLoad(slot: slot, timeout: configuration.fullScreenLoadTimeout)
            switch outcome {
            case .timedOut:
                AdsKit.shared.emit(format, slot, .failed(.timedOut))
                return .skipped(.timedOut)
            case .finished:
                cached = validCached(slot)
            }
        }

        guard let cached else {
            let error = lastErrors[slot] ?? .noAdUnitId
            return .skipped(error)
        }
        guard let presenter = viewController ?? TopViewController.find() else {
            return .skipped(.noPresenter)
        }

        // Bỏ khỏi kho *trước khi* hiện: một quảng cáo chỉ hiện được một lần, và
        // giữ lại là mời lượt sau hiện đúng cái vừa cháy.
        cache[slot] = nil

        let result = await action(cached.ad, presenter, FullScreenAdPresenter(format: format, slot: slot))

        // Nạp lại ngay để lượt sau không phải chờ.
        preload(slot: slot)
        return result
    }

    private enum LoadOutcome: Sendable { case finished, timedOut }

    private func waitForLoad(slot: AdSlot, timeout: TimeInterval) async -> LoadOutcome {
        let task = loadTask(for: slot)
        return await withTaskGroup(of: LoadOutcome.self) { group in
            group.addTask {
                await task.value
                return .finished
            }
            group.addTask {
                try? await Task.sleep(nanoseconds: UInt64(max(0, timeout) * 1_000_000_000))
                return .timedOut
            }
            let first = await group.next() ?? .timedOut
            group.cancelAll()
            return first
        }
    }
}
