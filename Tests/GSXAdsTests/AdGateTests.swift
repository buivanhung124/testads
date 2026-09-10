import XCTest
@testable import GSXAds
@testable import GSXCore

@MainActor
final class AdGateTests: XCTestCase {

    private var configurationCũ: AdsConfiguration?

    override func setUp() async throws {
        configurationCũ = AdsKit.shared.configuration
        EntitlementCenter.shared.setPurchased(false)
        EntitlementCenter.shared.isAdsRemovedManually = false
    }

    override func tearDown() async throws {
        AdsKit.shared.configuration = configurationCũ
        EntitlementCenter.shared.setPurchased(false)
        EntitlementCenter.shared.isAdsRemovedManually = false
    }

    func test_chưaConfigure() {
        AdsKit.shared.configuration = nil
        XCTAssertEqual(AdGate.check(.banner), .notConfigured)
    }

    func test_tắtQuảngCáo() {
        AdsKit.shared.configuration = AdsConfiguration(isTestMode: true, isEnabled: false)
        XCTAssertEqual(AdGate.check(.banner), .adsDisabled)
    }

    /// Đã mua thì chặn trước cả khi hỏi tới id hay mạng — người đã trả tiền
    /// không phải chờ một lần kiểm tra nào nữa.
    func test_đãMuaThìChặnNgay() {
        AdsKit.shared.configuration = AdsConfiguration(isTestMode: true)
        EntitlementCenter.shared.setPurchased(true)
        XCTAssertEqual(AdGate.check(.interstitial), .purchased)
    }

    func test_gỡQuảngCáoBằngĐườngKhácCũngChặn() {
        AdsKit.shared.configuration = AdsConfiguration(isTestMode: true)
        EntitlementCenter.shared.isAdsRemovedManually = true
        XCTAssertEqual(AdGate.check(.native), .purchased)
    }

    func test_khôngCóIdChoĐịnhDạngĐó() {
        AdsKit.shared.configuration = AdsConfiguration(
            units: AdUnits(banner: ["chỉ-có-banner"]),
            isTestMode: false
        )
        XCTAssertNil(AdGate.check(.banner, requiresConsent: false))
        XCTAssertEqual(AdGate.check(.rewarded), .noAdUnitId)
    }

    /// Chưa xin xong đồng ý thì chưa được hỏi quảng cáo — đây là hai lần kiểm
    /// tra mà bản UIKit viết thiếu `return` nên vẫn chạy tiếp xuống lệnh tải.
    func test_chưaCóĐồngÝThìKhôngTải() {
        AdsKit.shared.configuration = AdsConfiguration(isTestMode: true)
        // `AdsKit.start()` chưa chạy trong môi trường test, nên UMP chưa cho
        // phép và SDK chưa khởi động.
        let lýDo = AdGate.check(.banner)
        XCTAssertTrue(
            lýDo == .consentNotObtained || lýDo == .sdkNotStarted || lýDo == .noNetwork,
            "phải chặn lại, nhận được: \(String(describing: lýDo))"
        )
    }
}
