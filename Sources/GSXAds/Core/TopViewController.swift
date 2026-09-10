import UIKit

/// Màn hình đang ở trên cùng.
///
/// Quảng cáo toàn màn hình của GMA cần một `UIViewController` để hiện lên.
/// SwiftUI không đưa ra cái nào, nên tìm từ scene đang hoạt động — và tìm lại ở
/// đúng lúc hiện chứ không giữ sẵn, vì màn hình lúc *tải* quảng cáo thường
/// không còn là màn hình lúc *hiện* nó.
@MainActor
public enum TopViewController {

    public static func find() -> UIViewController? {
        guard let root = keyWindow?.rootViewController else { return nil }
        return topMost(of: root)
    }

    static var keyWindow: UIWindow? {
        UIApplication.shared.connectedScenes
            .compactMap { $0 as? UIWindowScene }
            .first { $0.activationState == .foregroundActive }?
            .windows.first(where: \.isKeyWindow)
        ?? UIApplication.shared.connectedScenes
            .compactMap { $0 as? UIWindowScene }
            .flatMap(\.windows)
            .first(where: \.isKeyWindow)
    }

    private static func topMost(of controller: UIViewController) -> UIViewController {
        if let presented = controller.presentedViewController, !presented.isBeingDismissed {
            return topMost(of: presented)
        }
        if let nav = controller as? UINavigationController, let visible = nav.visibleViewController {
            return topMost(of: visible)
        }
        if let tab = controller as? UITabBarController, let selected = tab.selectedViewController {
            return topMost(of: selected)
        }
        return controller
    }
}
