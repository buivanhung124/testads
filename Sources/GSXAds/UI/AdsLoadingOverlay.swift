import SwiftUI

/// Màn chờ trong lúc một quảng cáo toàn màn hình đang được tải.
///
/// Thay cho `RappleProgressHUD` — bốn file UIKit chỉ để hiện đúng một dòng chữ
/// "Loading Ads…". Ở đây là một View, dùng đúng màu và cỡ chữ của hệ thống, và
/// tự hiện tự tắt theo `AdsPresentationState`.
public struct AdsLoadingOverlay: View {

    @Environment(\.colorScheme) private var colorScheme

    public init() {}

    public var body: some View {
        let state = AdsKit.shared.presentation
        if state.isLoading {
            ZStack {
                Color.black.opacity(0.35)
                    .ignoresSafeArea()

                VStack(spacing: 12) {
                    ProgressView()
                        .controlSize(.large)
                    if !state.loadingText.isEmpty {
                        Text(state.loadingText)
                            .font(.subheadline)
                            .foregroundStyle(.secondary)
                    }
                }
                .padding(24)
                .background(.regularMaterial, in: RoundedRectangle(cornerRadius: 16, style: .continuous))
            }
            // Chặn thao tác bên dưới: quảng cáo sắp hiện lên, và một cú bấm lọt
            // xuống lúc này là một màn hình đã đi tiếp rồi mà quảng cáo vẫn nhảy
            // ra đè lên.
            .contentShape(Rectangle())
            .onTapGesture {}
            .transition(.opacity)
            .zIndex(999)
        }
    }
}
