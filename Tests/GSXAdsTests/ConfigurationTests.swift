import XCTest
@testable import GSXAds

final class ConfigurationTests: XCTestCase {

    func test_chếĐộTestKhôngĐụngTớiIdThật() {
        let thật = AdUnits(banner: ["banner-thật"], interstitial: ["inter-thật"])
        var configuration = AdsConfiguration(units: thật, isTestMode: true)

        XCTAssertEqual(configuration.ids(for: .banner), AdUnits.test.banner)
        XCTAssertNotEqual(configuration.ids(for: .banner), thật.banner)

        configuration.isTestMode = false
        XCTAssertEqual(configuration.ids(for: .banner), ["banner-thật"])
    }

    func test_mọiĐịnhDạngĐềuCóIdTest() {
        for format in AdType.allCases {
            XCTAssertFalse(AdUnits.test.ids(for: format).isEmpty, "\(format.rawValue) thiếu id test")
        }
    }

    func test_idTestĐúngLàCủaGoogle() {
        for format in AdType.allCases {
            for id in AdUnits.test.ids(for: format) {
                XCTAssertTrue(id.hasPrefix("ca-app-pub-3940256099942544/"), "\(id) không phải id test của Google")
            }
        }
    }

    func test_mỗiĐịnhDạngLấyĐúngDanhSáchCủaMình() {
        let units = AdUnits(
            appOpen: ["open"], banner: ["banner"], native: ["native"],
            interstitial: ["inter"], rewarded: ["reward"], rewardedInterstitial: ["reward-inter"]
        )
        XCTAssertEqual(units.ids(for: .appOpen), ["open"])
        XCTAssertEqual(units.ids(for: .banner), ["banner"])
        XCTAssertEqual(units.ids(for: .native), ["native"])
        XCTAssertEqual(units.ids(for: .interstitial), ["inter"])
        XCTAssertEqual(units.ids(for: .rewarded), ["reward"])
        XCTAssertEqual(units.ids(for: .rewardedInterstitial), ["reward-inter"])
    }

    /// Những lý do này là hoạt động đúng, không phải hỏng hóc — log không được
    /// kêu ầm lên vì chúng.
    func test_lýDoNàoLàLỗiThật() {
        XCTAssertFalse(AdError.adsDisabled.isFailure)
        XCTAssertFalse(AdError.purchased.isFailure)
        XCTAssertFalse(AdError.pacing.isFailure)
        XCTAssertFalse(AdError.tooSoon.isFailure)

        XCTAssertTrue(AdError.noNetwork.isFailure)
        XCTAssertTrue(AdError.timedOut.isFailure)
        XCTAssertTrue(AdError.google("no fill").isFailure)
    }

    func test_tênĐịnhDạngGửiChoThốngKê() {
        XCTAssertEqual(AdType.banner.analyticsName, "Banner")
        XCTAssertEqual(AdType.interstitial.analyticsName, "Interstitial")
        XCTAssertEqual(AdType.rewarded.analyticsName, "Rewarded")
        XCTAssertEqual(AdType.appOpen.analyticsName, "AppOpen")
    }
}
