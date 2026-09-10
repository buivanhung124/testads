import SwiftUI
import GSXAds

struct DemoView: View {

    @State private var lastResult = "—"

    var body: some View {
        NavigationStack {
            List {
                Section("Native") {
                    NativeAdSlot(slot: "demo-small", style: .small)
                        .listRowInsets(EdgeInsets(top: 6, leading: 12, bottom: 6, trailing: 12))
                    NativeAdSlot(slot: "demo-medium", style: .medium)
                        .listRowInsets(EdgeInsets(top: 6, leading: 12, bottom: 6, trailing: 12))
                }

                Section("Native tự viết bố cục") {
                    NativeAdSlot(slot: "demo-custom") {
                        VStack(alignment: .leading, spacing: 8) {
                            HStack(spacing: 10) {
                                NativeIcon(size: 40)
                                VStack(alignment: .leading, spacing: 2) {
                                    NativeHeadline(lines: 1)
                                    NativeAdvertiser()
                                }
                                Spacer()
                                NativeAdBadge()
                            }
                            NativeMedia(aspectRatio: 21 / 9)
                            NativeCallToAction()
                                .frame(maxWidth: .infinity, minHeight: 44)
                        }
                        .padding(12)
                        .background(Color(.tertiarySystemBackground))
                        .clipShape(RoundedRectangle(cornerRadius: 14, style: .continuous))
                    }
                    .listRowInsets(EdgeInsets(top: 6, leading: 12, bottom: 6, trailing: 12))
                }

                Section("Toàn màn hình") {
                    Button("Interstitial") {
                        Task { lastResult = "\(await AdsKit.shared.interstitial.show(slot: .exit))" }
                    }
                    Button("Rewarded") {
                        Task { lastResult = "\(await AdsKit.shared.rewarded.show(slot: "demo"))" }
                    }
                    Button("App Open (lần mở app)") {
                        Task { lastResult = "\(await AdsKit.shared.appOpen.showOnLaunch())" }
                    }
                    LabeledContent("Kết quả", value: lastResult)
                        .font(.footnote)
                }

                Section("Trạng thái") {
                    LabeledContent("SDK sẵn sàng", value: AdsKit.shared.isReady ? "rồi" : "chưa")
                    LabeledContent("Interstitial có sẵn", value: AdsKit.shared.interstitial.isReady(slot: .exit) ? "có" : "không")
                }
            }
            .navigationTitle("GSXAdsKit")
        }
        .preloadInterstitial(slot: .exit)
        .safeAreaInset(edge: .bottom) {
            BannerAd(slot: "demo-banner")
        }
    }
}
