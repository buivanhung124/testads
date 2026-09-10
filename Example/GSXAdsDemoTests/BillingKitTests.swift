import XCTest
import StoreKit
import StoreKitTest
import GSXBilling
import GSXCore

/// Mua bán thật, chạy trên `SKTestSession` — cửa hàng giả lập của Xcode.
///
/// Không phải mock: đây là StoreKit thật, giao dịch thật, chỉ có tiền là không
/// thật. Nên những thứ khó dựng lại bằng tay — hết hạn, hoàn tiền, Ask to Buy —
/// đều kiểm được ở đây.
///
/// **Chạy bằng Xcode** (⌘U). Qua `xcodebuild test` ở dòng lệnh thì trên một số
/// máy cửa hàng giả lập không dựng lên được — `SKTestSession` khởi tạo xong
/// nhưng không có gói nào, kèm `SKInternalErrorDomain Code=3` trong log. Gặp
/// cảnh đó thì cả nhóm này tự bỏ qua thay vì báo đỏ, vì lúc ấy cái hỏng là môi
/// trường chứ không phải SDK. Phần *tính toán* của thanh toán — loại gói, giá
/// quy về tuần, phần trăm tiết kiệm — nằm ở `Tests/GSXBillingTests` và chạy
/// được ở mọi nơi.
@MainActor
final class BillingKitTests: XCTestCase {

    private static let weekly = "gsx.demo.weekly"
    private static let yearly = "gsx.demo.yearly"
    private static let lifetime = "gsx.demo.lifetime"

    private var session: SKTestSession!
    private var billing: BillingKit { .shared }

    override func setUp() async throws {
        session = try Self.makeSession()
        session.disableDialogs = true
        session.askToBuyEnabled = false
        session.clearTransactions()

        EntitlementCenter.shared.setPurchased(false)
        billing.configure(productIds: [Self.weekly, Self.yearly, Self.lifetime])
        await billing.load()

        try XCTSkipIf(
            billing.plans.isEmpty,
            "Cửa hàng giả lập không dựng lên được — chạy nhóm này bằng Xcode (⌘U)."
        )
    }

    override func tearDown() async throws {
        session.clearTransactions()
        await billing.refreshEntitlements()
        session = nil
    }

    /// Dựng cửa hàng giả lập, hoặc bỏ qua cả nhóm nếu máy này không dựng được.
    ///
    /// Mở từ một **bản sao ghi được**: `SKTestSession` ghi trạng thái ngược vào
    /// chính file nó mở lên, mà bản nằm trong bundle test thì chỉ đọc.
    private static func makeSession() throws -> SKTestSession {
        let bundle = Bundle(for: BillingKitTests.self)
        guard let bundled = bundle.url(forResource: "Products", withExtension: "storekit") else {
            throw XCTSkip("Không tìm thấy Products.storekit trong bundle test.")
        }
        let copy = FileManager.default.temporaryDirectory
            .appendingPathComponent("GSXBillingTests-\(UUID().uuidString).storekit")
        try FileManager.default.copyItem(at: bundled, to: copy)

        do {
            return try SKTestSession(contentsOf: copy)
        } catch {
            throw XCTSkip("Không dựng được cửa hàng giả lập trên máy này: \(error.localizedDescription)")
        }
    }

    // MARK: - Tải gói

    func test_tảiĐủGóiVàGiữNguyênThứTựĐãKhai() {
        XCTAssertTrue(billing.isLoaded)
        XCTAssertEqual(billing.plans.map(\.id), [Self.weekly, Self.yearly, Self.lifetime],
                       "thứ tự khai là thứ tự màn hình bán hàng bày ra")
    }

    /// Id sai chính tả là lý do thường gặp nhất khiến màn hình bán hàng trống
    /// trơn. Những id còn lại vẫn phải lên được.
    func test_idKhôngTồnTạiKhôngKéoĐổNhữngIdCònLại() async {
        billing.configure(productIds: [Self.weekly, "gsx.demo.gõ.nhầm", Self.lifetime])
        await billing.load()

        XCTAssertEqual(billing.plans.map(\.id), [Self.weekly, Self.lifetime])
    }

    func test_khôngKhaiIdNàoThìKhôngHỏngGì() async {
        billing.configure(productIds: [])
        await billing.load()

        XCTAssertTrue(billing.plans.isEmpty)
        XCTAssertTrue(billing.isLoaded, "vẫn phải báo đã tải xong, để màn hình thôi quay vòng")
    }

    // MARK: - Mua

    func test_muaGóiTuầnThìĐượcQuyềnLợi() async throws {
        let plan = try XCTUnwrap(billing.plan(Self.weekly))

        let kếtQuả = await billing.purchase(plan)

        XCTAssertEqual(kếtQuả, .bought)
        XCTAssertTrue(billing.isPurchased)
        XCTAssertTrue(EntitlementCenter.shared.isAdsRemoved, "mua xong là quảng cáo phải tắt ngay")
    }

    func test_muaTrọnĐời() async throws {
        let plan = try XCTUnwrap(billing.plan(Self.lifetime))

        let kếtQuả = await billing.purchase(plan)
        XCTAssertEqual(kếtQuả, .bought)
        XCTAssertTrue(billing.isPurchased)
    }

    /// Giao dịch chưa kết thúc sẽ được App Store gửi lại ở **mọi** lần mở app,
    /// mãi mãi. Đây là bài test canh chừng điều đó.
    func test_giaoDịchĐượcKếtThúcHẳn() async throws {
        let plan = try XCTUnwrap(billing.plan(Self.yearly))
        _ = await billing.purchase(plan)

        var cònTreo: [String] = []
        for await result in Transaction.unfinished {
            if case let .verified(transaction) = result {
                cònTreo.append(transaction.productID)
            }
        }
        XCTAssertTrue(cònTreo.isEmpty, "còn treo: \(cònTreo)")
    }

    func test_góiKhôngCóTrongDanhSáchThìKhôngMuaĐược() async {
        let kếtQuả = await billing.purchase(productId: "gsx.demo.không.có")
        XCTAssertEqual(kếtQuả, .unavailable)
        XCTAssertFalse(billing.isPurchased)
    }

    /// Ask to Buy: cha mẹ duyệt sau. Chưa duyệt thì chưa có quyền lợi, và app
    /// không được mở khoá sớm.
    func test_chờNgườiKhácDuyệt() async throws {
        session.askToBuyEnabled = true
        let plan = try XCTUnwrap(billing.plan(Self.weekly))

        let kếtQuả = await billing.purchase(plan)
        XCTAssertEqual(kếtQuả, .pending)
        XCTAssertFalse(billing.isPurchased)
    }

    // MARK: - Khôi phục

    func test_khôiPhụcTrênMáyMới() async throws {
        let plan = try XCTUnwrap(billing.plan(Self.yearly))
        _ = await billing.purchase(plan)

        // Giả lập máy mới: quyền lợi ghi nhớ trong máy đã mất, nhưng tài khoản
        // Apple thì vẫn đang sở hữu gói.
        EntitlementCenter.shared.setPurchased(false)

        let khôiPhụcĐược = await billing.restore()

        XCTAssertTrue(khôiPhụcĐược)
        XCTAssertTrue(EntitlementCenter.shared.isAdsRemoved)
    }

    /// Chưa mua gì thì đọc lại quyền lợi cũng ra tay trắng.
    ///
    /// Cố ý **không** gọi `restore()` ở đây: đường đó kết thúc bằng
    /// `AppStore.sync()`, thứ mở hộp thoại đăng nhập Tài khoản Apple và đứng
    /// đó chờ — trên máy chạy test thì không có ai bấm, và bài test treo vĩnh
    /// viễn. Nhánh `restore()` *tìm thấy* gói đã được
    /// `test_khôiPhụcTrênMáyMới` kiểm, và nhánh đó không đụng tới `sync`.
    func test_chưaMuaGìThìKhôngCóQuyềnLợi() async {
        await billing.refreshEntitlements()
        XCTAssertFalse(billing.isPurchased)
        XCTAssertFalse(EntitlementCenter.shared.isAdsRemoved)
    }

    // MARK: - Mất quyền lợi

    func test_góiHếtHạnThìQuảngCáoQuayLại() async throws {
        let plan = try XCTUnwrap(billing.plan(Self.weekly))
        _ = await billing.purchase(plan)
        XCTAssertTrue(billing.isPurchased)

        try session.expireSubscription(productIdentifier: Self.weekly)
        await billing.refreshEntitlements()

        XCTAssertFalse(billing.isPurchased)
        XCTAssertFalse(EntitlementCenter.shared.isAdsRemoved)
    }

    func test_hoànTiềnThìMấtQuyềnLợi() async throws {
        let plan = try XCTUnwrap(billing.plan(Self.lifetime))
        _ = await billing.purchase(plan)
        XCTAssertTrue(billing.isPurchased)

        let giaoDịch = try XCTUnwrap(session.allTransactions().first { $0.productIdentifier == Self.lifetime })
        try session.refundTransaction(identifier: giaoDịch.identifier)
        await billing.refreshEntitlements()

        XCTAssertFalse(billing.isPurchased)
    }

    // MARK: - Thông tin gói

    func test_đọcĐúngLoạiGóiTừChuKỳChứKhôngPhảiTừTênId() throws {
        XCTAssertEqual(try XCTUnwrap(billing.plan(Self.weekly)).kind, .weekly)
        XCTAssertEqual(try XCTUnwrap(billing.plan(Self.yearly)).kind, .yearly)
        XCTAssertEqual(try XCTUnwrap(billing.plan(Self.lifetime)).kind, .lifetime)
    }

    func test_dùngThửMiễnPhí() throws {
        let weekly = try XCTUnwrap(billing.plan(Self.weekly))
        XCTAssertTrue(weekly.hasFreeTrial)
        XCTAssertEqual(weekly.introductoryOfferText, "3 ngày miễn phí")

        let yearly = try XCTUnwrap(billing.plan(Self.yearly))
        XCTAssertFalse(yearly.hasFreeTrial)
        XCTAssertNil(yearly.introductoryOfferText)
    }

    func test_giáQuyVềMộtTuần() throws {
        let weekly = try XCTUnwrap(billing.plan(Self.weekly))
        let yearly = try XCTUnwrap(billing.plan(Self.yearly))
        let lifetime = try XCTUnwrap(billing.plan(Self.lifetime))

        XCTAssertNotNil(weekly.pricePerWeek)
        XCTAssertNotNil(yearly.pricePerWeek)
        XCTAssertNil(lifetime.pricePerWeek, "chia một khoản trọn đời cho số tuần là con số vô nghĩa")
    }

    /// Nhãn "-60%" phải là con số thật, tính từ giá thật.
    func test_tínhPhầnTrămTiếtKiệm() throws {
        let weekly = try XCTUnwrap(billing.plan(Self.weekly))
        let yearly = try XCTUnwrap(billing.plan(Self.yearly))

        // 1.99/tuần so với 39.99/năm ≈ 0.77/tuần → rẻ hơn khoảng 61%.
        let phầnTrăm = try XCTUnwrap(yearly.savingsPercent(comparedTo: weekly))
        XCTAssertEqual(phầnTrăm, 61, accuracy: 2)

        XCTAssertNil(weekly.savingsPercent(comparedTo: yearly), "gói đắt hơn thì không có gì để khoe")
        XCTAssertNil(weekly.savingsPercent(comparedTo: weekly), "so với chính nó thì không tiết kiệm được gì")
    }

    func test_giáLuônLấyTừAppStore() throws {
        let weekly = try XCTUnwrap(billing.plan(Self.weekly))
        XCTAssertTrue(weekly.displayPrice.contains("1.99") || weekly.displayPrice.contains("1,99"),
                      "nhận được: \(weekly.displayPrice)")
        XCTAssertFalse(weekly.displayName.isEmpty)
    }
}
