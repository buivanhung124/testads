import XCTest
@testable import GSXAds

final class PacingTests: XCTestCase {

    /// `start: 2, loop: 3` nghĩa là lần 2, 5, 8… — đúng cách đếm của bản UIKit.
    func test_lầnThứMấyThìHiện() {
        let pacing = InterstitialPacing(start: 2, loop: 3)
        let hiện = (1...12).filter { pacing.shouldShow(at: $0) }
        XCTAssertEqual(hiện, [2, 5, 8, 11])
    }

    func test_lầnNàoCũngHiện() {
        let pacing = InterstitialPacing.everyTime
        XCTAssertEqual((1...5).filter { pacing.shouldShow(at: $0) }, [1, 2, 3, 4, 5])
    }

    func test_khôngHiệnTrướcLượtĐầu() {
        let pacing = InterstitialPacing(start: 3, loop: 1)
        XCTAssertFalse(pacing.shouldShow(at: 1))
        XCTAssertFalse(pacing.shouldShow(at: 2))
        XCTAssertTrue(pacing.shouldShow(at: 3))
        XCTAssertTrue(pacing.shouldShow(at: 4), "loop 1 thì từ lượt đầu trở đi lần nào cũng hiện")
    }

    /// Số 0 hay số âm lọt vào từ cấu hình từ xa thì kẹp lại, chứ không được
    /// chia cho 0.
    func test_sốKhôngHợpLệBịKẹpLại() {
        let pacing = InterstitialPacing(start: 0, loop: 0)
        XCTAssertEqual(pacing.start, 1)
        XCTAssertEqual(pacing.loop, 1)
        XCTAssertTrue(pacing.shouldShow(at: 1))

        let âm = InterstitialPacing(start: -5, loop: -2)
        XCTAssertEqual(âm.start, 1)
        XCTAssertEqual(âm.loop, 1)
    }

    /// Mỗi vị trí đếm riêng: ba lần thoát màn hình A không được màn hình B đếm hộ.
    @MainActor
    func test_mỗiVịTríĐếmRiêng() {
        let center = AdsKit.shared.interstitial
        center.resetPacing(slot: "A")
        center.resetPacing(slot: "B")

        let pacing = InterstitialPacing(start: 2, loop: 2)

        XCTAssertFalse(center.consumePacing(pacing, slot: "A"), "A lần 1")
        XCTAssertFalse(center.consumePacing(pacing, slot: "B"), "B lần 1")
        XCTAssertTrue(center.consumePacing(pacing, slot: "A"), "A lần 2")
        XCTAssertTrue(center.consumePacing(pacing, slot: "B"), "B lần 2")

        center.resetPacing(slot: "A")
        XCTAssertFalse(center.consumePacing(pacing, slot: "A"), "đặt lại rồi thì A đếm từ đầu")
    }
}
