import XCTest
import AppTrackingTransparency
@testable import GSXAds

/// Xin quyền theo dõi — phần kiểm được mà không cần ai bấm.
///
/// Hộp thoại ATT thật thì phải có người bấm mới xong, nên bài test không dựng
/// lại được nó. Cái kiểm ở đây là hai nhánh *không* hỏi — và đó đúng là hai
/// nhánh nguy hiểm, vì nếu chúng chờ nhầm thì cả tầng quảng cáo đứng im theo.
@MainActor
final class TrackingAuthorizationTests: XCTestCase {

    /// Bundle chạy test không khai `NSUserTrackingUsageDescription`, nên đây là
    /// đúng nhánh "app chưa khai lý do".
    func test_thiếuLýDoTrongInfoPlistThìKhôngHỏiVàKhôngChờ() async {
        let mốc = Date()
        let đồngÝ = await ConsentManager.shared.requestTrackingAuthorization(timeout: 30)

        XCTAssertFalse(đồngÝ)
        XCTAssertLessThan(
            Date().timeIntervalSince(mốc), 1,
            "phải trả lời ngay — chờ hết 30 giây ở đây là treo cả lần khởi động"
        )
    }

    func test_khôngBaoGiờTựĐổiTrạngThái() async {
        let trước = ConsentManager.shared.trackingStatus
        _ = await ConsentManager.shared.requestTrackingAuthorization(timeout: 1)
        XCTAssertEqual(ConsentManager.shared.trackingStatus, trước)
    }

    /// Cờ bật/tắt phải đi thẳng từ cấu hình, không có tầng nào diễn giải lại.
    func test_cờTrongCấuHình() {
        var configuration = AdsConfiguration(isTestMode: true)
        XCTAssertTrue(configuration.requestsAppTracking, "mặc định là có hỏi")

        configuration.requestsAppTracking = false
        XCTAssertFalse(configuration.requestsAppTracking)
    }
}
