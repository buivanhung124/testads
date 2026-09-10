import XCTest
@testable import GSXAds

@MainActor
final class PresentationStateTests: XCTestCase {

    func test_đangHiệnThìKhôngChoCáiThứHaiChenVào() {
        let state = AdsPresentationState()
        state.isPresenting = true
        XCTAssertEqual(state.canStartFullScreen(minimumInterval: 0), .alreadyPresenting)
    }

    func test_đangTảiCũngLàĐangBận() {
        let state = AdsPresentationState()
        state.isLoading = true
        XCTAssertTrue(state.isBusy)
        XCTAssertEqual(state.canStartFullScreen(minimumInterval: 0), .alreadyPresenting)
    }

    func test_rảnhThìĐiTiếp() {
        let state = AdsPresentationState()
        XCTAssertNil(state.canStartFullScreen(minimumInterval: 0))
    }

    func test_chưaHếtQuãngNghỉ() {
        let state = AdsPresentationState()
        state.lastDismissedAt = Date().addingTimeInterval(-5)
        XCTAssertEqual(state.canStartFullScreen(minimumInterval: 30), .tooSoon)
        XCTAssertNil(state.canStartFullScreen(minimumInterval: 3), "5 giây trước, quãng nghỉ 3 giây thì đã đủ")
    }

    func test_khôngĐặtQuãngNghỉThìKhôngChặn() {
        let state = AdsPresentationState()
        state.lastDismissedAt = Date()
        XCTAssertNil(state.canStartFullScreen(minimumInterval: 0))
    }
}
