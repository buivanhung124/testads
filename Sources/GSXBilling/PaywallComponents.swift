import SwiftUI
import StoreKit

/// Một thẻ gói để chọn.
///
/// Không tự quyết định gì: nhận gói, nhận trạng thái đang chọn, báo ra cú bấm.
/// Mọi con chữ về giá đều lấy từ `BillingPlan`, nên không có chỗ nào để một
/// con số cũ lọt vào.
public struct PlanCard: View {

    private let plan: BillingPlan
    private let isSelected: Bool
    private let badge: String?
    private let action: () -> Void

    public init(
        plan: BillingPlan,
        isSelected: Bool,
        badge: String? = nil,
        action: @escaping () -> Void
    ) {
        self.plan = plan
        self.isSelected = isSelected
        self.badge = badge
        self.action = action
    }

    public var body: some View {
        Button(action: action) {
            HStack(spacing: 12) {
                Image(systemName: isSelected ? "largecircle.fill.circle" : "circle")
                    .font(.title3)
                    .foregroundStyle(isSelected ? Color.accentColor : Color.secondary)

                VStack(alignment: .leading, spacing: 2) {
                    HStack(spacing: 6) {
                        Text(plan.displayName)
                            .font(.headline)
                        if let badge {
                            Text(badge)
                                .font(.caption2.bold())
                                .padding(.horizontal, 6)
                                .padding(.vertical, 2)
                                .background(Color.accentColor, in: Capsule())
                                .foregroundStyle(.white)
                        }
                    }
                    if let offer = plan.introductoryOfferText {
                        Text(offer)
                            .font(.footnote)
                            .foregroundStyle(.secondary)
                    } else if let perWeek = plan.pricePerWeek {
                        Text("\(perWeek)/tuần")
                            .font(.footnote)
                            .foregroundStyle(.secondary)
                    }
                }

                Spacer(minLength: 8)

                Text(plan.displayPrice)
                    .font(.headline)
                    .monospacedDigit()
            }
            .padding(14)
            .frame(maxWidth: .infinity)
            .background(Color(uiColor: .secondarySystemBackground), in: RoundedRectangle(cornerRadius: 14, style: .continuous))
            .overlay {
                RoundedRectangle(cornerRadius: 14, style: .continuous)
                    .strokeBorder(isSelected ? Color.accentColor : Color.clear, lineWidth: 2)
            }
        }
        .buttonStyle(.plain)
    }
}

/// Nút mua chính.
public struct PurchaseButton: View {

    private let title: String
    private let isBusy: Bool
    private let action: () -> Void

    public init(title: String = "Tiếp tục", isBusy: Bool = false, action: @escaping () -> Void) {
        self.title = title
        self.isBusy = isBusy
        self.action = action
    }

    public var body: some View {
        Button(action: action) {
            ZStack {
                Text(title)
                    .font(.headline)
                    .opacity(isBusy ? 0 : 1)
                if isBusy { ProgressView().tint(.white) }
            }
            .frame(maxWidth: .infinity, minHeight: 52)
        }
        .buttonStyle(.borderedProminent)
        .controlSize(.large)
        .disabled(isBusy)
    }
}

/// Hàng liên kết bắt buộc ở chân màn hình bán hàng.
///
/// Apple yêu cầu có Khôi phục, Điều khoản và Chính sách riêng tư trên mọi màn
/// hình bán gói đăng ký — thiếu là một lý do bị từ chối duyệt.
public struct PaywallFooter: View {

    private let termsURL: URL?
    private let privacyURL: URL?
    private let onRestore: () -> Void

    public init(termsURL: URL?, privacyURL: URL?, onRestore: @escaping () -> Void) {
        self.termsURL = termsURL
        self.privacyURL = privacyURL
        self.onRestore = onRestore
    }

    public var body: some View {
        HStack(spacing: 14) {
            Button("Khôi phục", action: onRestore)
            if let termsURL {
                Link("Điều khoản", destination: termsURL)
            }
            if let privacyURL {
                Link("Riêng tư", destination: privacyURL)
            }
        }
        .font(.caption)
        .foregroundStyle(.secondary)
    }
}

/// Màn hình bán hàng dựng sẵn, dùng được ngay.
///
/// Cố tình để mộc: đây là chỗ mỗi app có thiết kế riêng, nên phần đáng dùng lại
/// là mấy mảnh ở trên và cái luồng ở đây — tải gói, chọn, mua, khôi phục, đóng
/// khi xong — chứ không phải bộ mặt của nó.
public struct SubscriptionPaywall: View {

    private let title: String
    private let features: [String]
    private let termsURL: URL?
    private let privacyURL: URL?
    private let onClose: () -> Void

    @State private var selectedId: String?
    @State private var billing = BillingKit.shared

    public init(
        title: String = "Mở khoá bản đầy đủ",
        features: [String] = [],
        termsURL: URL? = nil,
        privacyURL: URL? = nil,
        onClose: @escaping () -> Void
    ) {
        self.title = title
        self.features = features
        self.termsURL = termsURL
        self.privacyURL = privacyURL
        self.onClose = onClose
    }

    public var body: some View {
        VStack(spacing: 0) {
            HStack {
                Spacer()
                Button(action: onClose) {
                    Image(systemName: "xmark")
                        .font(.body.weight(.semibold))
                        .foregroundStyle(.secondary)
                        .padding(8)
                }
            }
            .padding(.horizontal, 8)

            ScrollView {
                VStack(alignment: .leading, spacing: 18) {
                    Text(title)
                        .font(.largeTitle.bold())

                    if !features.isEmpty {
                        VStack(alignment: .leading, spacing: 8) {
                            ForEach(features, id: \.self) { feature in
                                Label(feature, systemImage: "checkmark.circle.fill")
                                    .foregroundStyle(.primary)
                            }
                        }
                    }

                    if billing.isLoaded {
                        VStack(spacing: 10) {
                            ForEach(billing.plans) { plan in
                                PlanCard(
                                    plan: plan,
                                    isSelected: selectedId == plan.id,
                                    badge: badge(for: plan)
                                ) {
                                    selectedId = plan.id
                                }
                            }
                        }
                    } else {
                        ProgressView().frame(maxWidth: .infinity, minHeight: 120)
                    }
                }
                .padding(20)
            }

            VStack(spacing: 12) {
                PurchaseButton(isBusy: billing.isBusy) {
                    Task { await buy() }
                }
                .disabled(selectedId == nil)

                PaywallFooter(termsURL: termsURL, privacyURL: privacyURL) {
                    Task {
                        await billing.restore()
                        if billing.isPurchased { onClose() }
                    }
                }
            }
            .padding(20)
        }
        .task {
            if !billing.isLoaded { await billing.load() }
            // Chọn sẵn gói rẻ nhất theo tuần — gói đáng chọn nhất, chứ không
            // phải gói đắt nhất.
            selectedId = selectedId ?? bestValuePlan?.id ?? billing.plans.first?.id
        }
    }

    private var bestValuePlan: BillingPlan? {
        billing.plans.first { $0.kind == .yearly } ?? billing.plans.first { $0.kind == .lifetime }
    }

    private func badge(for plan: BillingPlan) -> String? {
        guard let weekly = billing.plans.first(where: { $0.kind == .weekly }),
              weekly.id != plan.id,
              let percent = plan.savingsPercent(comparedTo: weekly)
        else { return nil }
        return "-\(percent)%"
    }

    private func buy() async {
        guard let selectedId, let plan = billing.plan(selectedId) else { return }
        if await billing.purchase(plan).didBuy { onClose() }
    }
}
