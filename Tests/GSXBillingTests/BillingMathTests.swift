import XCTest
@testable import GSXBilling

/// Những con số in thẳng lên màn hình bán hàng.
final class BillingMathTests: XCTestCase {

    // MARK: - Quy về tuần

    func test_sốTuầnCủaTừngChuKỳ() {
        XCTAssertEqual(BillingPeriod(unit: .week, value: 1).approximateWeeks, 1)
        XCTAssertEqual(BillingPeriod(unit: .month, value: 1).approximateWeeks, 4)
        XCTAssertEqual(BillingPeriod(unit: .month, value: 6).approximateWeeks, 24)
        XCTAssertEqual(BillingPeriod(unit: .year, value: 1).approximateWeeks, 52)
        XCTAssertEqual(BillingPeriod(unit: .day, value: 7).approximateWeeks, 1)
    }

    /// Chu kỳ ngắn hơn một tuần vẫn phải ra ít nhất 1, nếu không thì phép chia
    /// bên dưới chia cho 0.
    func test_chuKỳNgắnHơnMộtTuần() {
        XCTAssertEqual(BillingPeriod(unit: .day, value: 3).approximateWeeks, 1)
        XCTAssertEqual(BillingPeriod(unit: .day, value: 1).approximateWeeks, 1)
    }

    func test_giáQuyVềMộtTuần() {
        let yearly = BillingPeriod(unit: .year, value: 1)
        let perWeek = try? XCTUnwrap(BillingMath.pricePerWeek(Decimal(52), over: yearly))
        XCTAssertEqual(perWeek, Decimal(1))
    }

    func test_góiMuaĐứtKhôngCóGiáTheoTuần() {
        XCTAssertNil(BillingMath.pricePerWeek(Decimal(39.99), over: nil))
    }

    // MARK: - Loại gói

    func test_đọcLoạiGóiTừChuKỳ() {
        XCTAssertEqual(BillingMath.kind(period: BillingPeriod(unit: .week, value: 1), isNonConsumable: false), .weekly)
        XCTAssertEqual(BillingMath.kind(period: BillingPeriod(unit: .day, value: 7), isNonConsumable: false), .weekly)
        XCTAssertEqual(BillingMath.kind(period: BillingPeriod(unit: .month, value: 1), isNonConsumable: false), .monthly)
        XCTAssertEqual(BillingMath.kind(period: BillingPeriod(unit: .month, value: 3), isNonConsumable: false), .quarterly)
        XCTAssertEqual(BillingMath.kind(period: BillingPeriod(unit: .month, value: 6), isNonConsumable: false), .semiAnnual)
        XCTAssertEqual(BillingMath.kind(period: BillingPeriod(unit: .year, value: 1), isNonConsumable: false), .yearly)
    }

    func test_góiMuaĐứtLàTrọnĐời() {
        XCTAssertEqual(BillingMath.kind(period: nil, isNonConsumable: true), .lifetime)
    }

    func test_chuKỳLạThìKhôngĐoánBừa() {
        XCTAssertEqual(BillingMath.kind(period: BillingPeriod(unit: .month, value: 2), isNonConsumable: false), .other)
        XCTAssertEqual(BillingMath.kind(period: nil, isNonConsumable: false), .other)
    }

    // MARK: - Phần trăm tiết kiệm

    /// 1.99/tuần so với 39.99/năm (≈0.769/tuần) → rẻ hơn khoảng 61%.
    func test_phầnTrămTiếtKiệmLàConSốThật() {
        let yearlyPerWeek = BillingMath.pricePerWeek(Decimal(string: "39.99")!, over: BillingPeriod(unit: .year, value: 1))
        let weeklyPerWeek = BillingMath.pricePerWeek(Decimal(string: "1.99")!, over: BillingPeriod(unit: .week, value: 1))

        let percent = BillingMath.savingsPercent(weekly: yearlyPerWeek, comparedTo: weeklyPerWeek)
        XCTAssertEqual(try XCTUnwrap(percent), 61, accuracy: 1)
    }

    func test_khôngRẻHơnThìKhôngCóNhãn() {
        XCTAssertNil(BillingMath.savingsPercent(weekly: Decimal(2), comparedTo: Decimal(1)))
        XCTAssertNil(BillingMath.savingsPercent(weekly: Decimal(1), comparedTo: Decimal(1)), "bằng nhau thì không tiết kiệm gì")
    }

    func test_thiếuGiáThìKhôngTínhBừa() {
        XCTAssertNil(BillingMath.savingsPercent(weekly: nil, comparedTo: Decimal(1)))
        XCTAssertNil(BillingMath.savingsPercent(weekly: Decimal(1), comparedTo: nil))
        XCTAssertNil(BillingMath.savingsPercent(weekly: Decimal(1), comparedTo: Decimal(0)), "không chia cho 0")
    }

    // MARK: - Chữ

    func test_chữMôTảChuKỳ() {
        XCTAssertEqual(BillingPeriod(unit: .day, value: 3).localizedText, "3 ngày")
        XCTAssertEqual(BillingPeriod(unit: .week, value: 1).localizedText, "1 tuần")
        XCTAssertEqual(BillingPeriod(unit: .month, value: 6).localizedText, "6 tháng")
        XCTAssertEqual(BillingPeriod(unit: .year, value: 1).localizedText, "1 năm")
    }
}
