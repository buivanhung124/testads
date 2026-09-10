// swift-tools-version: 5.9
import PackageDescription

let package = Package(
    name: "GSXAdsKit",
    platforms: [.iOS(.v17)],
    products: [
        .library(name: "GSXAds", targets: ["GSXAds"]),
        .library(name: "GSXBilling", targets: ["GSXBilling"]),
        .library(name: "GSXCore", targets: ["GSXCore"]),
    ],
    dependencies: [
        .package(
            url: "https://github.com/googleads/swift-package-manager-google-mobile-ads.git",
            .upToNextMajor(from: "13.9.0")
        ),
        .package(
            url: "https://github.com/googleads/swift-package-manager-google-user-messaging-platform.git",
            .upToNextMajor(from: "3.1.0")
        ),
    ],
    targets: [
        // Nền chung: log, mạng, quyền lợi (đã mua hay chưa).
        // Không phụ thuộc AdMob lẫn StoreKit nên hai module trên đứng cạnh nhau
        // được mà không kéo theo nhau.
        .target(name: "GSXCore"),

        .target(
            name: "GSXAds",
            dependencies: [
                "GSXCore",
                .product(name: "GoogleMobileAds", package: "swift-package-manager-google-mobile-ads"),
                .product(name: "GoogleUserMessagingPlatform", package: "swift-package-manager-google-user-messaging-platform"),
            ]
        ),

        .target(name: "GSXBilling", dependencies: ["GSXCore"]),

        // Chạy trên iOS Simulator:
        //   xcodebuild test -scheme GSXAdsKit-Package \
        //     -destination 'platform=iOS Simulator,name=iPhone 17 Pro'
        .testTarget(name: "GSXCoreTests", dependencies: ["GSXCore"]),
        .testTarget(name: "GSXAdsTests", dependencies: ["GSXAds"]),
        // Phần tính toán của thanh toán. Những gì cần tới *cửa hàng* — mua,
        // khôi phục, hết hạn, hoàn tiền — nằm ở `Example/GSXAdsDemoTests`, vì
        // `SKTestSession` đòi một app thật làm chỗ đứng.
        .testTarget(name: "GSXBillingTests", dependencies: ["GSXBilling"]),
    ]
)
