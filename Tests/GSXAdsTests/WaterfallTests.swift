import XCTest
@testable import GSXAds

final class WaterfallTests: XCTestCase {

    private struct FakeAd: Equatable { let unitId: String }

    /// Đây là điểm khác hẳn bản UIKit: id đầu không lấp được thì id sau được
    /// thử **ngay trong cùng một lần**, chứ không phải đợi tới lượt gọi sau.
    func test_thửTiếpIdSauKhiIdTrướcHỏng() async throws {
        var đãThử: [String] = []

        let kếtQuả = try await AdWaterfall.load(ids: ["a", "b", "c"], format: .interstitial) { id in
            đãThử.append(id)
            guard id == "c" else { throw AdError.google("no fill") }
            return FakeAd(unitId: id)
        }

        XCTAssertEqual(đãThử, ["a", "b", "c"])
        XCTAssertEqual(kếtQuả.unitId, "c")
        XCTAssertEqual(kếtQuả.ad, FakeAd(unitId: "c"))
    }

    func test_dừngNgayKhiIdĐầuLấpĐược() async throws {
        var đãThử: [String] = []

        let kếtQuả = try await AdWaterfall.load(ids: ["a", "b", "c"], format: .banner) { id in
            đãThử.append(id)
            return FakeAd(unitId: id)
        }

        XCTAssertEqual(đãThử, ["a"], "lấp được rồi thì không hỏi thêm id nào nữa")
        XCTAssertEqual(kếtQuả.unitId, "a")
    }

    func test_hếtIdThìNémLỗiCuốiCùng() async {
        do {
            _ = try await AdWaterfall.load(ids: ["a", "b"], format: .native) { id in
                throw AdError.google("hỏng ở \(id)")
            }
            XCTFail("phải ném lỗi khi không id nào lấp được")
        } catch {
            XCTAssertEqual(error as? AdError, .google("hỏng ở b"), "lỗi báo về là của lần thử cuối")
        }
    }

    func test_danhSáchRỗng() async {
        do {
            _ = try await AdWaterfall.load(ids: [], format: .native) { _ in FakeAd(unitId: "x") }
            XCTFail("phải ném lỗi")
        } catch {
            XCTAssertEqual(error as? AdError, .noAdUnitId)
        }
    }
}
