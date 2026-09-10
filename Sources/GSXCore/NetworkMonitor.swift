import Foundation
import Network
import Observation

/// Có mạng hay không.
///
/// Thay cho `SCNetworkReachability` đời cũ: `NWPathMonitor` báo *đẩy* mỗi khi
/// đường mạng đổi, nên không phải hỏi lại ở từng lần gọi quảng cáo, và trạng
/// thái là thứ SwiftUI quan sát được.
@MainActor
@Observable
public final class NetworkMonitor {

    public static let shared = NetworkMonitor()

    /// Khởi tạo là `true` chứ không phải `false`: `NWPathMonitor` trả lời sau
    /// một nhịp, và chặn quảng cáo trong nhịp đó là chặn oan đúng lúc màn hình
    /// đầu tiên vừa mở.
    public private(set) var isConnected = true

    private let monitor = NWPathMonitor()
    private let queue = DispatchQueue(label: "com.gsx.adskit.network")

    private init() {
        monitor.pathUpdateHandler = { [weak self] path in
            let connected = path.status == .satisfied
            Task { @MainActor [weak self] in
                guard let self, self.isConnected != connected else { return }
                self.isConnected = connected
                GSXLog.debug("[net] \(connected ? "online" : "offline")")
            }
        }
        monitor.start(queue: queue)
    }
}
