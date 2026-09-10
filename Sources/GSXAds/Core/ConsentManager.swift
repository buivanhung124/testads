import UIKit
import Observation
import AppTrackingTransparency
import UserMessagingPlatform
import GSXCore

/// Hỏi đồng ý (GDPR) qua User Messaging Platform.
///
/// Bọc UMP lại thành `async` và giữ đúng một mảnh trạng thái mà app cần biết:
/// `isPresentingForm`. Không có nó thì màn hình onboarding rất dễ dựng hộp thoại
/// đánh giá đè lên form đồng ý — hai hộp thoại hệ thống chồng nhau ở lần chạy
/// đầu, và cái thứ hai là cái không ai đọc.
@MainActor
@Observable
public final class ConsentManager {

    public static let shared = ConsentManager()

    /// UMP đã cho phép yêu cầu quảng cáo chưa. Ở ngoài vùng GDPR thì đúng gần
    /// như ngay lập tức.
    public var canRequestAds: Bool { ConsentInformation.shared.canRequestAds }

    /// App có phải bày mục "Tuỳ chọn riêng tư" trong Cài đặt hay không.
    public var isPrivacyOptionsRequired: Bool {
        ConsentInformation.shared.privacyOptionsRequirementStatus == .required
    }

    /// Đang có form đồng ý trên màn hình.
    public private(set) var isPresentingForm = false

    /// Vùng địa lý giả lập lúc debug. Đặt `.EEA` để thấy form ngay tại Việt Nam.
    public var debugGeography: DebugGeography = .disabled

    /// Thiết bị được UMP coi là máy test. Lấy id trong log ở lần chạy đầu.
    public var debugDeviceIdentifiers: [String] = []

    private init() {}

    /// Xin đồng ý nếu cần, rồi trả về.
    ///
    /// Không ném lỗi ra ngoài để chặn luồng khởi động: UMP hỏng thì
    /// `canRequestAds` tự khắc `false` và mọi định dạng lặng lẽ không tải —
    /// còn app thì vẫn phải mở lên được.
    @discardableResult
    public func gather(from viewController: UIViewController? = nil) async -> AdError? {
        let parameters = RequestParameters()
        #if DEBUG
        if debugGeography != .disabled || !debugDeviceIdentifiers.isEmpty {
            let settings = DebugSettings()
            settings.geography = debugGeography
            settings.testDeviceIdentifiers = debugDeviceIdentifiers
            parameters.debugSettings = settings
        }
        #endif

        if let error = await requestInfoUpdate(parameters) {
            GSXLog.error("[consent] update lỗi: \(error.localizedDescription)")
            return .google(error.localizedDescription)
        }

        // Không hỏi trước được là có form hay không: `loadAndPresentIfRequired`
        // tự quyết, và với thông điệp ATT thì `consentStatus` vẫn báo
        // `.notRequired`. Nên bật cờ quanh trọn lời gọi — không có gì để hiện
        // thì nó trả về ngay và cờ chỉ bật trong chớp mắt, vô hại.
        let presenter = viewController ?? TopViewController.find()
        isPresentingForm = true
        defer { isPresentingForm = false }

        do {
            try await ConsentForm.loadAndPresentIfRequired(from: presenter)
            GSXLog.debug("[consent] xong, canRequestAds = \(canRequestAds)")
            return nil
        } catch {
            GSXLog.error("[consent] form lỗi: \(error.localizedDescription)")
            return .google(error.localizedDescription)
        }
    }

    /// Mở lại form riêng tư — gắn vào một dòng trong màn hình Cài đặt, và chỉ
    /// bày dòng đó khi `isPrivacyOptionsRequired` đúng.
    public func presentPrivacyOptions(from viewController: UIViewController? = nil) async -> AdError? {
        let presenter = viewController ?? TopViewController.find()
        isPresentingForm = true
        defer { isPresentingForm = false }
        do {
            try await ConsentForm.presentPrivacyOptionsForm(from: presenter)
            return nil
        } catch {
            return .google(error.localizedDescription)
        }
    }

    // MARK: - Quyền theo dõi (ATT)

    /// Trạng thái quyền theo dõi hiện tại.
    public var trackingStatus: ATTrackingManager.AuthorizationStatus {
        ATTrackingManager.trackingAuthorizationStatus
    }

    /// Xin quyền theo dõi, nếu app đã khai lý do trong Info.plist.
    ///
    /// Gọi **sau** khi form đồng ý của UMP đã đóng: hai hộp thoại hệ thống
    /// chồng nhau ở lần chạy đầu là ấn tượng đầu tiên của người dùng về app, và
    /// cái thứ hai là cái không ai đọc.
    ///
    /// Thiếu `NSUserTrackingUsageDescription` trong Info.plist thì lặng lẽ bỏ
    /// qua — hỏi mà không nói được vì sao hỏi là một lời xin không có gì đằng
    /// sau, và cũng đúng là thứ App Review đánh trượt.
    ///
    /// - Parameter timeout: chờ tối đa bấy nhiêu giây rồi đi tiếp.
    ///   Hộp thoại ATT đứng đó tới khi có người bấm, và mọi thứ phía sau —
    ///   khởi động SDK quảng cáo, tải banner đầu tiên — đang xếp hàng sau nó.
    ///   Người dùng bình thường bấm trong vài giây; hạn chờ này là để một
    ///   trường hợp bất thường (app bị đẩy xuống nền đúng lúc hỏi) không làm
    ///   app đứng im mãi.
    /// - Returns: `true` nếu người dùng đồng ý.
    @discardableResult
    public func requestTrackingAuthorization(timeout: TimeInterval = 30) async -> Bool {
        guard hasTrackingUsageDescription else {
            GSXLog.debug("[att] Info.plist thiếu NSUserTrackingUsageDescription — không hỏi")
            return false
        }
        guard trackingStatus == .notDetermined else {
            return trackingStatus == .authorized
        }

        let answered = await withTaskGroup(of: Bool?.self) { group in
            group.addTask {
                let status = await ATTrackingManager.requestTrackingAuthorization()
                return status == .authorized
            }
            group.addTask {
                try? await Task.sleep(nanoseconds: UInt64(max(0, timeout) * 1_000_000_000))
                return nil
            }
            let first = await group.next() ?? nil
            group.cancelAll()
            return first
        }

        guard let answered else {
            GSXLog.debug("[att] hết hạn chờ, đi tiếp")
            return false
        }
        GSXLog.debug("[att] \(answered ? "đồng ý" : "từ chối")")
        return answered
    }

    private var hasTrackingUsageDescription: Bool {
        let value = Bundle.main.object(forInfoDictionaryKey: "NSUserTrackingUsageDescription") as? String
        return !(value ?? "").isEmpty
    }

    /// Xoá trạng thái đồng ý. Chỉ dùng lúc thử, đừng gọi trong bản phát hành.
    public func reset() {
        ConsentInformation.shared.reset()
    }

    private func requestInfoUpdate(_ parameters: RequestParameters) async -> Error? {
        await withCheckedContinuation { continuation in
            ConsentInformation.shared.requestConsentInfoUpdate(with: parameters) { error in
                continuation.resume(returning: error)
            }
        }
    }
}
