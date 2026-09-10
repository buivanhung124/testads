import XCTest
@testable import GSXCore

@MainActor
final class EntitlementCenterTests: XCTestCase {

    private var defaults: UserDefaults!
    private var center: EntitlementCenter!

    override func setUp() async throws {
        // Kho riêng cho mỗi lần chạy, để một bài test không đọc phải thứ bài
        // trước để lại.
        defaults = UserDefaults(suiteName: "gsx.tests.\(UUID().uuidString)")
        center = EntitlementCenter(defaults: defaults)
    }

    func test_mặcĐịnhChưaMua() {
        XCTAssertFalse(center.isPurchased)
        XCTAssertFalse(center.isAdsRemoved)
    }

    func test_muaRồiThìGỡQuảngCáo() {
        center.setPurchased(true)
        XCTAssertTrue(center.isPurchased)
        XCTAssertTrue(center.isAdsRemoved)
    }

    /// Cờ phải sống qua lần mở app sau, nếu không thì mỗi lần khởi động lại là
    /// một lần loé quảng cáo trước mặt người đã trả tiền.
    func test_giữLạiGiữaCácLầnMởApp() {
        center.setPurchased(true)

        let saukhiMởLại = EntitlementCenter(defaults: defaults)
        XCTAssertTrue(saukhiMởLại.isPurchased)
    }

    func test_gỡQuảngCáoBằngĐườngKhácKhôngPhảiLàĐãMua() {
        center.isAdsRemovedManually = true
        XCTAssertTrue(center.isAdsRemoved)
        XCTAssertFalse(center.isPurchased, "thưởng hay mã khuyến mãi không phải một giao dịch")
    }

    func test_hoànTiềnThìQuảngCáoQuayLại() {
        center.setPurchased(true)
        center.setPurchased(false)
        XCTAssertFalse(center.isAdsRemoved)
    }
}
