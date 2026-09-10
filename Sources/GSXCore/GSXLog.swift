import Foundation
import os

/// Log của SDK.
///
/// Mặc định chỉ in ở bản DEBUG: tầng quảng cáo rất "nói nhiều" và không có gì
/// trong đó nên lọt vào log của bản release. App muốn bật ở TestFlight thì đặt
/// `GSXLog.isEnabled = true`.
public enum GSXLog {

    public static var isEnabled: Bool = {
        #if DEBUG
        return true
        #else
        return false
        #endif
    }()

    private static let logger = Logger(subsystem: "com.gsx.adskit", category: "GSXAdsKit")

    public static func debug(_ message: @autoclosure () -> String) {
        guard isEnabled else { return }
        // Gọi ra biến trước: nội suy của `Logger` giữ lại closure, mà một
        // `@autoclosure` không phải escaping thì không cho giữ.
        let text = message()
        logger.debug("\(text, privacy: .public)")
    }

    public static func error(_ message: @autoclosure () -> String) {
        guard isEnabled else { return }
        let text = message()
        logger.error("\(text, privacy: .public)")
    }
}
