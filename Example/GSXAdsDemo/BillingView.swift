import SwiftUI
import GSXAds
import GSXBilling

/// Màn hình mua bán của app thử.
///
/// Chạy trên file `Products.storekit` gắn vào scheme, nên mua được thật mà
/// không cần App Store Connect và không mất đồng nào. Mua xong thì mọi ô quảng
/// cáo ở tab kia tự biến mất — đó là toàn bộ chỗ nối giữa hai module.
struct BillingView: View {

    @State private var billing = BillingKit.shared
    @State private var entitlement = EntitlementCenter.shared
    @State private var selected: String?
    @State private var lastResult = "—"
    @State private var showPaywall = false

    var body: some View {
        NavigationStack {
            List {
                Section("Trạng thái") {
                    LabeledContent("Đã mua", value: billing.isPurchased ? "rồi" : "chưa")
                    LabeledContent("Quảng cáo", value: entitlement.isAdsRemoved ? "đã tắt" : "đang bật")
                    LabeledContent("Đang bận", value: billing.isBusy ? "có" : "không")
                    LabeledContent("Kết quả", value: lastResult).font(.footnote)
                }

                Section("Gói") {
                    if billing.isLoaded {
                        ForEach(billing.plans) { plan in
                            PlanCard(
                                plan: plan,
                                isSelected: selected == plan.id,
                                badge: badge(for: plan)
                            ) {
                                selected = plan.id
                            }
                            .listRowInsets(EdgeInsets(top: 4, leading: 12, bottom: 4, trailing: 12))
                        }
                    } else {
                        ProgressView().frame(maxWidth: .infinity)
                    }
                }

                Section {
                    PurchaseButton(isBusy: billing.isBusy) {
                        Task { await buy() }
                    }
                    .disabled(selected == nil)

                    Button("Khôi phục") {
                        Task {
                            let ok = await billing.restore()
                            lastResult = ok ? "khôi phục được" : "không có gì để khôi phục"
                        }
                    }
                    Button("Mở màn hình bán hàng dựng sẵn") { showPaywall = true }
                    Button("Quản lý gói đăng ký") {
                        Task { await billing.showManageSubscriptions() }
                    }
                }

                Section("Chi tiết gói") {
                    ForEach(billing.plans) { plan in
                        VStack(alignment: .leading, spacing: 2) {
                            Text(plan.displayName).font(.subheadline.bold())
                            Text("loại: \(plan.kind.rawValue) · giá: \(plan.displayPrice)")
                            if let perWeek = plan.pricePerWeek {
                                Text("quy về tuần: \(perWeek)")
                            }
                            if let offer = plan.introductoryOfferText {
                                Text("ưu đãi đầu: \(offer)")
                            }
                        }
                        .font(.caption)
                        .foregroundStyle(.secondary)
                    }
                }
            }
            .navigationTitle("Billing")
        }
        .sheet(isPresented: $showPaywall) {
            SubscriptionPaywall(
                title: "Mở khoá bản đầy đủ",
                features: ["Không quảng cáo", "Không giới hạn", "Hỗ trợ nhanh"],
                termsURL: URL(string: "https://example.com/terms"),
                privacyURL: URL(string: "https://example.com/privacy")
            ) {
                showPaywall = false
            }
        }
        .task {
            if !billing.isLoaded { await billing.load() }
            selected = selected ?? billing.plans.first?.id
        }
    }

    private func badge(for plan: BillingPlan) -> String? {
        guard let weekly = billing.plans.first(where: { $0.kind == .weekly }), weekly.id != plan.id,
              let percent = plan.savingsPercent(comparedTo: weekly)
        else { return nil }
        return "-\(percent)%"
    }

    private func buy() async {
        guard let selected, let plan = billing.plan(selected) else { return }
        lastResult = "\(await billing.purchase(plan))"
    }
}
