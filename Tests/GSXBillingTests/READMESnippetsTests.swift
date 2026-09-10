import XCTest
import SwiftUI
@testable import GSXBilling

/// Các đoạn mã thanh toán trong README — kiểm rằng chúng biên dịch được.
@MainActor
final class READMESnippetsTests: XCTestCase {

    func test_mọiVíDụĐềuBiênDịchĐược() {
        XCTAssertNotNil(Self.self)
    }

    private func mục9_khaiVàBật() {
        BillingKit.shared.configure(productIds: ["app.sub.weekly", "app.sub.yearly", "app.lifetime"])
        BillingKit.shared.start()
    }

    private func mục9_muaVàKhôiPhục() async {
        let billing = BillingKit.shared
        guard let plan = billing.plans.first else { return }

        if await billing.purchase(plan).didBuy { print("xong") }
        _ = await billing.purchase(productId: plan.id)
        _ = await billing.restore()
        await billing.refreshEntitlements()
        await billing.showManageSubscriptions()
        _ = (billing.isPurchased, billing.isBusy, billing.isLoaded, billing.plan(plan.id))

        billing.onPurchase = { product in _ = product.id }
    }

    private func mục9_giáVàNhãn() {
        guard let plan = BillingKit.shared.plans.first,
              let weekly = BillingKit.shared.plans.first(where: { $0.kind == .weekly })
        else { return }

        _ = (plan.displayName, plan.displayPrice, plan.productDescription,
             plan.pricePerWeek, plan.introductoryOfferText, plan.hasFreeTrial,
             plan.kind, plan.period, plan.isSubscription, plan.id)
        _ = plan.savingsPercent(comparedTo: weekly)
    }

    private func mục9_khôngDùngGSXBilling() {
        EntitlementCenter.shared.setPurchased(true)
    }
}

/// Màn hình bán hàng ở mục 9 — là một View thật, vì `@State` chỉ sống được
/// trong một View.
private struct PaywallSnippet: View {

    @State private var billing = BillingKit.shared
    @State private var selected: String?
    @State private var showPaywall = false

    var body: some View {
        VStack {
            ForEach(billing.plans) { plan in
                PlanCard(plan: plan, isSelected: selected == plan.id) { selected = plan.id }
            }

            PurchaseButton(isBusy: billing.isBusy) {
                Task {
                    guard let selected, let plan = billing.plan(selected) else { return }
                    _ = await billing.purchase(plan).didBuy
                }
            }

            PaywallFooter(termsURL: nil, privacyURL: nil) {
                Task { await billing.restore() }
            }
        }
        .sheet(isPresented: $showPaywall) {
            SubscriptionPaywall(
                title: "Mở khoá bản đầy đủ",
                features: ["Không quảng cáo", "Cảnh báo tức thì", "Không giới hạn địa điểm"],
                termsURL: URL(string: "https://example.com/terms"),
                privacyURL: URL(string: "https://example.com/privacy")
            ) { showPaywall = false }
        }
    }
}
