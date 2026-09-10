import SwiftUI
import GSXAds
import GSXBilling

/// App thử của SDK.
///
/// Chạy bằng id test công khai của Google, nên mọi ô đều lấp được quảng cáo mà
/// không đụng tới tài khoản AdMob nào.
@main
struct GSXAdsDemoApp: App {

    init() {
        AdsKit.shared.configure(AdsConfiguration(
            appId: AdUnits.testAppId,
            isTestMode: true,
            collapsibleBanner: .bottom,
            interstitialPacing: .everyTime
        ))

        AdsKit.shared.onEvent = { format, slot, event in
            print("[demo] \(format.rawValue):\(slot) → \(event)")
        }

        // Id trùng với Example/Products.storekit — file đã gắn vào scheme, nên
        // mua được ngay trên máy ảo, không cần App Store Connect.
        BillingKit.shared.configure(productIds: [
            "gsx.demo.weekly", "gsx.demo.yearly", "gsx.demo.lifetime",
        ])
        BillingKit.shared.start()

        BillingKit.shared.onPurchase = { product in
            print("[demo] đã mua \(product.id) — \(product.displayPrice)")
        }
    }

    var body: some Scene {
        WindowGroup {
            RootTabs()
                .gsxAds()
        }
    }
}


/// Hai tab: quảng cáo và mua bán. Mua ở tab này thì tab kia sạch quảng cáo.
struct RootTabs: View {

    /// Mở thẳng vào một tab: `xcrun simctl launch <máy> com.gsx.adskit.demo -startTab billing`
    @State private var selection = UserDefaults.standard.string(forKey: "startTab") == "billing" ? 1 : 0

    var body: some View {
        TabView(selection: $selection) {
            DemoView()
                .tabItem { Label("Quảng cáo", systemImage: "rectangle.on.rectangle") }
                .tag(0)
            BillingView()
                .tabItem { Label("Billing", systemImage: "creditcard") }
                .tag(1)
        }
    }
}
