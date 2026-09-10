# GSXAdsKit

SDK quảng cáo + thanh toán cho app **SwiftUI**, iOS 17+.

Viết lại từ tầng `Ads/` + `Store/Billing.swift` của `ios_bvh_disaster_tracker`, giữ nguyên
những gì đã chạy tốt (bộ điều kiện trước khi tải, danh sách id nhiều tầng, nhịp hiện
interstitial, đối chiếu app id) và bỏ những gì chỉ tồn tại vì UIKit: callback gắn vào
`UIViewController`, `Timer` dò mỗi giây, file `.xib` cho native, HUD ngoài, biến toàn cục.

| | |
|---|---|
| **Định dạng** | Banner · Native · Interstitial · Rewarded · Rewarded Interstitial · App Open |
| **Đồng ý** | UMP (GDPR) + ATT, tự động |
| **Thanh toán** | StoreKit 2 — gói đăng ký và mua đứt |
| **Yêu cầu** | iOS 17 · Xcode 16+ · GoogleMobileAds 13.9+ |

---

## Mục lục

**Bắt đầu** — [1. Cài vào dự án](#1-cài-vào-dự-án) · [2. Khởi động](#2-khởi-động) ·
[3. Đồng ý, ATT, quyền riêng tư](#3-đồng-ý-att-quyền-riêng-tư)

**Từng định dạng** — [4. Banner](#4-banner) · [5. Native](#5-native) ·
[6. Interstitial](#6-interstitial) · [7. Rewarded](#7-rewarded) · [8. App Open](#8-app-open)

**Tiền** — [9. Thanh toán](#9-thanh-toán) · [10. Mở khoá bằng quảng cáo](#10-mở-khoá-bằng-quảng-cáo) ·
[11. Ghi nhận doanh thu](#11-ghi-nhận-doanh-thu)

**Vận hành** — [12. Bật tắt từ xa](#12-bật-tắt-từ-xa) · [13. Xử lý sự cố](#13-xử-lý-sự-cố) ·
[14. Tham chiếu API](#14-tham-chiếu-api)

**Phụ lục** — [15. Chạy test](#15-chạy-test) · [16. App thử](#16-app-thử) ·
[17. Chuyển từ app UIKit](#17-chuyển-từ-app-uikit) · [18. Trước khi phát hành](#18-trước-khi-phát-hành)

---

## 1. Cài vào dự án

### Bước 1 — thêm package

**Xcode → File → Add Package Dependencies… → Add Local…** rồi chọn thư mục này.

Ở tab **General** của target, mục *Frameworks, Libraries, and Embedded Content*, thêm:

- `GSXAds`
- `GSXBilling` — bỏ qua nếu app không bán gì

Xcode tự kéo theo `GoogleMobileAds` và `GoogleUserMessagingPlatform`. `GSXCore` đi kèm sẵn,
không phải thêm.

### Bước 2 — Info.plist

```xml
<key>GADApplicationIdentifier</key>
<string>ca-app-pub-XXXXXXXXXXXX~YYYYYYYYYY</string>

<key>NSUserTrackingUsageDescription</key>
<string>Cho phép để chúng tôi hiển thị quảng cáo phù hợp hơn với bạn.</string>

<key>SKAdNetworkItems</key>
<array>
    <!-- dán nguyên danh sách trong tài liệu AdMob -->
</array>
```

| Khoá | Bắt buộc? | Thiếu thì sao |
|---|---|---|
| `GADApplicationIdentifier` | **Có** | Google Mobile Ads không khởi động được |
| `NSUserTrackingUsageDescription` | Nếu muốn xin ATT | SDK lặng lẽ bỏ qua ATT, doanh thu thấp hơn |
| `SKAdNetworkItems` | Nên có | Không đo được lượt cài đến từ quảng cáo |

Lúc chạy thử dùng id ứng dụng test của Google: `ca-app-pub-3940256099942544~1458002511`.

---

## 2. Khởi động

```swift
import SwiftUI
import GSXAds
import GSXBilling

@main
struct MyApp: App {

    init() {
        AdsKit.shared.configure(AdsConfiguration(
            units: AdUnits(
                appOpen:      ["ca-app-pub-.../..."],
                banner:       ["ca-app-pub-.../...", "ca-app-pub-.../..."],  // nhiều id = nhiều tầng dự phòng
                native:       ["ca-app-pub-.../..."],
                interstitial: ["ca-app-pub-.../..."],
                rewarded:     ["ca-app-pub-.../..."]
            ),
            appId: "ca-app-pub-XXXX~YYYY",
            isTestMode: true,          // đang phát triển: dùng id test của Google
            isEnabled: true,
            collapsibleBanner: .bottom,
            interstitialPacing: InterstitialPacing(start: 2, loop: 3)
        ))

        BillingKit.shared.configure(productIds: [
            "app.sub.weekly", "app.sub.yearly", "app.lifetime",
        ])
        BillingKit.shared.start()
    }

    var body: some Scene {
        WindowGroup {
            RootView()
                .gsxAds()
        }
    }
}
```

`.gsxAds()` gắn **một lần** ở View gốc. Nó chạy đúng thứ tự này:

```
xin đồng ý (UMP)  →  xin quyền theo dõi (ATT)  →  MobileAds.start()  →  isReady = true
                                                                            ↓
                                          banner và native đang chờ bắt đầu tải
                                                                            ↓
                                          tải sẵn App Open cho lần quay lại app
```

Ngoài ra nó dựng màn chờ cho quảng cáo toàn màn hình, hiện App Open mỗi lần người dùng quay
lại từ nền, và **xoá sạch quảng cáo đang giữ ngay khi có người mua**.

> Trước khi phát hành nhớ đổi `isTestMode: false`. Bấm vào quảng cáo thật bằng máy của mình
> là cách nhanh nhất để bị khoá tài khoản AdMob — lúc thử thì dùng `testDeviceIdentifiers`.

---

## 3. Đồng ý, ATT, quyền riêng tư

Cả ba đều tự động trong `.gsxAds()`, nhưng có ba việc app vẫn phải tự làm.

### Form riêng tư trong màn hình Cài đặt — bắt buộc

Google yêu cầu người dùng khu vực EU phải **đổi lại lựa chọn** của họ bất cứ lúc nào. Thiếu
mục này là vi phạm chính sách:

```swift
if ConsentManager.shared.isPrivacyOptionsRequired {
    Button("Tuỳ chọn riêng tư") {
        Task { await ConsentManager.shared.presentPrivacyOptions() }
    }
}
```

`isPrivacyOptionsRequired` chỉ đúng với người ở khu vực cần — chỗ khác thì dòng này không
hiện, và đó là chủ ý.

### Quyền theo dõi (ATT)

Mặc định SDK xin ngay sau khi form đồng ý đóng lại — không bao giờ hai hộp thoại cùng lúc.
Tự bỏ qua trong hai trường hợp: Info.plist chưa khai `NSUserTrackingUsageDescription`, hoặc
người dùng đã trả lời rồi. Trường hợp thứ hai hay gặp hơn ta tưởng: nếu tài khoản AdMob có
bật *ATT message*, thì chính UMP đã hiện màn giải thích và gọi hộp thoại ATT — lúc đó SDK
thấy câu trả lời đã có và không hỏi lại.

Hộp thoại ATT đứng đó tới khi có người bấm, và **mọi thứ phía sau đang xếp hàng sau nó** —
khởi động SDK quảng cáo, tải banner đầu tiên. Nên có hạn chờ 30 giây: người dùng bình thường
bấm trong vài giây, còn một trường hợp bất thường (app bị đẩy xuống nền đúng lúc hỏi) thì
app đi tiếp thay vì đứng im mãi.

Muốn tự chọn thời điểm hỏi — chẳng hạn ở trang cuối phần giới thiệu, nơi vừa kịp giải thích
vì sao — thì tắt đi rồi gọi tay:

```swift
AdsKit.shared.configuration?.requestsAppTracking = false
// … tới lúc thích hợp:
await ConsentManager.shared.requestTrackingAuthorization()
```

### Thử form đồng ý khi đang ở Việt Nam

Form GDPR chỉ hiện với người trong khu vực EU. Giả lập:

```swift
#if DEBUG
ConsentManager.shared.debugGeography = .EEA
ConsentManager.shared.debugDeviceIdentifiers = ["ID_MÁY_LẤY_TRONG_LOG"]
ConsentManager.shared.reset()   // xoá lựa chọn cũ để form hiện lại
#endif
```

Chạy lần đầu, log của UMP sẽ in ra id máy — dán vào `debugDeviceIdentifiers`.

---

## 4. Banner

```swift
ContentView()
    .safeAreaInset(edge: .bottom) { BannerAd() }
```

Tự đo bề rộng để lấy cỡ *large anchored adaptive*, tải lại khi xoay máy hoặc đổi bề rộng
cửa sổ (Split View trên iPad), giữ sẵn chỗ trong lúc tải để nội dung không giật, và **tự
biến mất** khi người dùng đã mua hoặc khi quảng cáo đang tắt — không cần một dòng `if` nào.

```swift
BannerAd(
    slot: "home",            // chỉ để đọc log và thống kê
    size: .adaptive,         // .compact = 320×50 nếu muốn chiếm ít chỗ
    collapsible: .bottom,    // nút thu gọn ở mép dưới; .top nếu banner nằm trên đầu
    reservesSpace: true      // giữ chỗ trong lúc tải
)
```

| Cỡ | Chiều cao | Ghi chú |
|---|---|---|
| `.adaptive` | 50–150pt, Google tính theo máy | Cỡ **duy nhất** nhận được banner co lại được |
| `.compact` | 50pt cố định | Chiếm ít chỗ, giá thầu thấp hơn |

Ở bề rộng máy tính bảng (≥ 728pt) SDK tự đổi sang leaderboard 728×90 và **tự tắt
collapsible** — hai thứ đó không đi cùng nhau được, hỏi cả hai thì banner trả về một khoảng
trống.

---

## 5. Native

### Khuôn dựng sẵn

```swift
NativeAdSlot(slot: "feed", style: .medium)
```

| Khuôn | Bố cục | Cao khoảng |
|---|---|---|
| `.small` | một hàng: icon · tiêu đề · nút | 76pt |
| `.medium` | icon · tiêu đề · mô tả · ảnh 1.91:1 · nút | 355pt |
| `.large` | ảnh 1.91:1 trên cùng · icon · tiêu đề · mô tả · nút | 385pt |

Chèn vào danh sách mà không muốn nó giật khi quảng cáo hiện ra:

```swift
NativeAdSlot(slot: "feed", style: .medium, reservesSpace: true)
```

### Đổi giao diện

```swift
RootView()
    .nativeAdTheme(NativeAdTheme(
        background: Color(.secondarySystemBackground),
        cornerRadius: 16,
        headlineColor: .primary,
        ctaBackground: .accentColor,
        ctaForeground: .white,
        badgeText: "Quảng cáo"
    ))
```

Gắn ở đâu thì mọi ô native bên trong đó theo — như mọi environment của SwiftUI.

### Tự viết bố cục

Bằng SwiftUI thuần, không `.xib`, không `viewWithTag`:

```swift
NativeAdSlot(slot: "feed") {
    VStack(alignment: .leading, spacing: 8) {
        NativeMedia(aspectRatio: 4 / 3)
        HStack(spacing: 10) {
            NativeIcon(size: 40)
            VStack(alignment: .leading) {
                NativeHeadline(lines: 2)
                NativeAdvertiser()
            }
            Spacer()
            NativeAdBadge()
        }
        NativeBody(lines: 2)
        NativeCallToAction().frame(maxWidth: .infinity, minHeight: 44)
    }
    .padding(12)
}
```

| Mảnh | Luôn có? | Ghi chú |
|---|---|---|
| `NativeHeadline(lines:)` | **Có** | |
| `NativeMedia(aspectRatio:contentMode:)` | **Có** | Bỏ trống `aspectRatio` thì theo tỉ lệ thật của quảng cáo |
| `NativeBody(lines:)` | Không | |
| `NativeIcon(size:)` | Không | |
| `NativeCallToAction()` | Không | Cố ý **không** nhận `action` — cú bấm thuộc về Google |
| `NativeAdvertiser()` · `NativeStore()` · `NativePrice()` · `NativeStarRating()` | Không | |
| `NativeAdBadge()` | — | Nhãn "Ad", Google **bắt buộc** phải có |

Mảnh nào quảng cáo không có thì tự biến mất, không để lại khoảng trống. Mỗi mảnh tự đăng ký
với `NativeAdView` của Google nên lượt hiện và lượt bấm vẫn được đếm đúng — chạy ở chế độ
test, công cụ **AdMob native ad validator** của Google phải báo *"No implementation issues
found"*.

### Tự quản việc tải

Khi muốn tải sẵn từ trước, hoặc dùng chung một quảng cáo cho nhiều chỗ:

```swift
@State private var native = NativeAdController(slot: "feed")

// … native.load() · native.reload() · native.clear()
// … native.ad · native.isReady · native.isLoading · native.lastError
```

---

## 6. Interstitial

```swift
Button("Xong") {
    Task {
        await AdsKit.shared.interstitial.show(slot: .exit)
        dismiss()          // chạy dù có quảng cáo hay không
    }
}
```

Tải sẵn từ lúc vào màn hình để tới lúc bấm là hiện ngay:

```swift
DetailView()
    .preloadInterstitial(slot: .exit)
```

**Nhịp hiện.** `InterstitialPacing(start: 2, loop: 3)` nghĩa là lần thứ 2, 5, 8… Đếm riêng
cho từng `slot`, nên "cứ ba lần thoát màn hình A thì một quảng cáo" không bị màn hình B đếm
hộ. Ghi đè cho một lần gọi:

```swift
await AdsKit.shared.interstitial.show(slot: .exit, pacing: .everyTime)
```

**Luôn trả lời.** Quảng cáo tắt, chưa tới lượt, không có mạng, tải hỏng, hay lần hiện không
bao giờ đáp lại — mọi đường đều kết thúc bằng một câu trả lời, nên không có cách nào để một
nút back kẹt lại. Muốn biết vì sao:

```swift
switch await AdsKit.shared.interstitial.show(slot: .exit) {
case .shown:                 print("đã xem")
case .skipped(let lý_do):    print("bỏ qua: \(lý_do.localizedDescription)")
}
```

---

## 7. Rewarded

```swift
let result = await AdsKit.shared.rewarded.show(slot: "hint")
if result.isEarned { giveHint() }
```

| Kết quả | Nghĩa |
|---|---|
| `.earned(amount:type:)` | Xem đủ, được thưởng |
| `.dismissed` | Có hiện nhưng đóng sớm — **không** thưởng |
| `.skipped(AdError)` | Không hiện được, kèm lý do |

Không có nhịp: quảng cáo có thưởng là thứ người dùng chủ động đổi lấy một thứ gì đó, "chưa
tới lượt" ở đây vô nghĩa. Tải sẵn bằng `.preloadRewarded(slot:)`.

Rewarded interstitial dùng y hệt: `AdsKit.shared.rewardedInterstitial.show(slot:)`.

---

## 8. App Open

**Lần quay lại app** — `.gsxAds()` tự lo, không phải viết gì.

**Lần mở app từ đầu** — gọi ở màn splash, nơi có người đang đợi:

```swift
struct SplashView: View {
    let onFinish: () -> Void

    var body: some View {
        LogoView().task {
            await AdsKit.shared.startAndShowLaunchAd()
            onFinish()
        }
    }
}
```

> Ở **lần chạy đầu tiên** thì đừng hiện: đó là lúc app còn chưa kịp nói mình là gì, mà cũng
> là lúc form đồng ý đang chờ. Cách cũ vẫn đúng — chỉ hiện với người đã từng mở app:
>
> ```swift
> if UserDefaults.standard.bool(forKey: "hasSeenOnboarding") {
>     await AdsKit.shared.startAndShowLaunchAd()
> } else {
>     await AdsKit.shared.start()
> }
> ```

Tắt hẳn quảng cáo lúc quay lại app: `.gsxAds(appOpenOnForeground: false)`.

---

## 9. Thanh toán

### Khai và bật

```swift
BillingKit.shared.configure(productIds: ["app.sub.weekly", "app.sub.yearly", "app.lifetime"])
BillingKit.shared.start()
```

`start()` phải gọi **một lần lúc mở app**, không phải lúc mở màn hình bán hàng: một giao
dịch có thể hoàn tất khi app đang ở nền, hoặc được cha mẹ duyệt sau vài giờ qua Ask to Buy,
và nó về bất cứ lúc nào chuyện đó xảy ra. Thiếu thì giao dịch không bao giờ được kết thúc
và App Store gửi lại mãi.

### Màn hình bán hàng của app

```swift
@State private var billing = BillingKit.shared
@State private var selected: String?

ForEach(billing.plans) { plan in
    PlanCard(plan: plan, isSelected: selected == plan.id) { selected = plan.id }
}

PurchaseButton(isBusy: billing.isBusy) {
    Task {
        guard let selected, let plan = billing.plan(selected) else { return }
        if await billing.purchase(plan).didBuy { dismiss() }
    }
}

PaywallFooter(termsURL: termsURL, privacyURL: privacyURL) {
    Task { await billing.restore() }
}
```

Apple **bắt buộc** mọi màn hình bán gói đăng ký phải có đủ Khôi phục · Điều khoản · Chính
sách riêng tư — `PaywallFooter` là chỗ đó.

### Hoặc dùng thẳng màn hình mẫu

```swift
.sheet(isPresented: $showPaywall) {
    SubscriptionPaywall(
        title: "Mở khoá bản đầy đủ",
        features: ["Không quảng cáo", "Cảnh báo tức thì", "Không giới hạn địa điểm"],
        termsURL: URL(string: "https://…/terms"),
        privacyURL: URL(string: "https://…/privacy")
    ) { showPaywall = false }
}
```

### Giá và nhãn khuyến mãi

Giá **không bao giờ** viết cứng: mọi con số đều lấy từ `Product`, đã được App Store định
dạng theo cửa hàng người mua đang đứng.

```swift
plan.displayPrice              // "39.000₫" — App Store định dạng
plan.pricePerWeek              // quy về tuần, nil với gói mua đứt
plan.introductoryOfferText     // "3 ngày miễn phí"
plan.hasFreeTrial
plan.kind                      // .weekly · .monthly · .yearly · .lifetime …
plan.savingsPercent(comparedTo: weeklyPlan)   // 61 → in nhãn "-61%"
```

`savingsPercent` trả `nil` khi gói kia **không** rẻ hơn — nhãn "tiết kiệm" chỉ hiện khi có
thật.

### Nối với quảng cáo

Mua xong, `BillingKit` chép kết quả sang `EntitlementCenter`, và tầng quảng cáo đọc từ đó:
mọi banner, native biến mất **ngay trong phiên đang chạy**, không cần mở lại app.

Không dùng `GSXBilling` (RevenueCat, Adapty, máy chủ riêng)? Chỉ một dòng:

```swift
EntitlementCenter.shared.setPurchased(true)
```

### Thử mua mà không cần App Store Connect

Xcode → **File → New → File → StoreKit Configuration File**, khai gói vào đó, rồi
**Product → Scheme → Edit Scheme → Run → Options → StoreKit Configuration** chọn file vừa
tạo. Từ đó mua được ngay trên máy ảo, không mất đồng nào. Xem mẫu ở
[Example/Products.storekit](Example/Products.storekit).

---

## 10. Mở khoá bằng quảng cáo

Mô hình `isSetIAPToAds` của các app cũ: tính năng bị khoá mở ra bằng **một lần xem quảng
cáo** thay vì bằng tiền. SDK không ép app theo mô hình nào, nhưng đây là cách viết lại nó
cho SwiftUI:

```swift
@MainActor
enum Unlock {

    /// Từ Remote Config. `true` = mở bằng quảng cáo, `false` = mở bằng cách mua.
    static var byWatchingAd = false

    /// Mở một thứ đang khoá, theo cách mà bản dựng này chọn.
    static func feature(present paywall: () -> Void, then unlocked: @escaping () -> Void) async {
        // Đã mua thì không phải xem gì nữa.
        if EntitlementCenter.shared.isAdsRemoved { return unlocked() }

        if byWatchingAd {
            // Quảng cáo tắt thì cổng mở luôn, không kẹt.
            await AdsKit.shared.interstitial.show(slot: .unlock, pacing: .everyTime)
            unlocked()
        } else {
            paywall()
        }
    }
}
```

Dùng:

```swift
Button("Thêm địa điểm") {
    Task {
        await Unlock.feature(present: { showPaywall = true }) {
            addPlace()
        }
    }
}
```

Hai điều đáng giữ từ bản cũ: **quảng cáo tắt thì cổng mở luôn** (nếu không thì app tự khoá
chính mình bằng một chiếc chìa khoá không tồn tại), và **đường mua hàng không gọi
`unlocked()`** — mua là việc không xong trong vài giây, cánh cửa đó mở lại khi giao dịch
thật sự về, tức là khi `EntitlementCenter` đổi.

---

## 11. Ghi nhận doanh thu

SDK cố ý **không** kéo Firebase vào — gắn nó vào một package quảng cáo là bắt mọi app phải
kéo theo Firebase. Mọi sự kiện đi ra một chỗ:

```swift
AdsKit.shared.onEvent = { format, slot, event in
    guard case .paid(let revenue) = event else { return }
    Analytics.logEvent(AnalyticsEventAdImpression, parameters: [
        AnalyticsParameterValue: revenue.value,
        AnalyticsParameterCurrency: revenue.currencyCode,
        AnalyticsParameterAdPlatform: "AdMob",
        AnalyticsParameterAdUnitName: revenue.adUnitId,
        AnalyticsParameterAdFormat: revenue.format.analyticsName,
    ])
}

BillingKit.shared.onPurchase = { product in
    logAsaPurchase(amount: …, currency: …, productId: product.id)
}
```

| Sự kiện | Khi nào |
|---|---|
| `.loaded` | Tải xong, chưa hiện |
| `.failed(AdError)` | Không tải/hiện được — xem bảng lý do ở [mục 14](#aderror) |
| `.impression` | Đã tính một lượt hiện |
| `.click` | Có người bấm |
| `.opened` / `.closed` | Quảng cáo toàn màn hình mở ra / đóng lại |
| `.rewarded(amount:type:)` | Người dùng xem đủ và được thưởng |
| `.paid(AdRevenue)` | Google báo doanh thu của lượt hiện đó |

---

## 12. Bật tắt từ xa

`AdsKit.shared.configuration` sửa được bất cứ lúc nào — mọi định dạng đọc lại ở lần tải kế
tiếp, không giữ bản sao riêng:

```swift
// sau khi Remote Config trả lời
AdsKit.shared.configuration?.isEnabled = remote.adsEnabled
AdsKit.shared.configuration?.units.interstitial = remote.interstitialIds
AdsKit.shared.configuration?.interstitialPacing = InterstitialPacing(start: remote.start, loop: remote.loop)
```

Tắt `isEnabled` giữa chừng phiên thì banner và native trên màn hình biến mất ngay.

---

## 13. Xử lý sự cố

### Bật log

Mặc định log chỉ in ở bản DEBUG. Muốn xem ở TestFlight:

```swift
GSXLog.isEnabled = true
```

Log đi qua `os.Logger`, subsystem `com.gsx.adskit`. Xem trên máy ảo:

```bash
xcrun simctl spawn booted log stream --level debug --predicate 'subsystem == "com.gsx.adskit"'
```

Một lần khởi động khoẻ mạnh trông như thế này:

```
[ads] configure — test=true, enabled=true
[consent] xong, canRequestAds = true
[ads] Google Mobile Ads đã start
[banner:home] loaded
[banner:home] impression
[native:feed] loaded
[native] nối 6 thành phần
```

### Bảng triệu chứng

| Thấy gì | Nguyên nhân thường gặp |
|---|---|
| Không có log nào cả | Chưa gọi `configure`, hoặc chưa gắn `.gsxAds()` |
| `[ads] lệch app id` | `configuration.appId` khác `GADApplicationIdentifier` — Info.plist thắng |
| `failed — Không có ad unit id` | Định dạng đó chưa khai id, hoặc đang ở `isTestMode` nhầm |
| `failed — UMP chưa cho phép` | Người dùng từ chối, hoặc gọi trước khi `.gsxAds()` chạy xong |
| `failed — Người dùng đã mua` | Đúng như vậy, không phải lỗi |
| Banner trống, không log lỗi | Ô banner nằm trong View bị ẩn, hoặc bề rộng bằng 0 |
| Native không hiện, không log | Ô đặt trong `List` mà `canShow` còn `false` — chờ `isReady` |
| Ô native lòi nền hai bên ảnh | Ép `aspectRatio` khác tỉ lệ thật của quảng cáo; bỏ trống để theo tỉ lệ thật |
| Màn chờ đứng mãi | Đã có phanh 5 giây (hiện) và `fullScreenLoadTimeout` (tải) — nếu vẫn kẹt, xem log `timedOut` |
| Màn hình bán hàng không có giá | Product id không khớp App Store Connect — log `[billing] không có trong App Store Connect: …` |
| Hộp thoại "Yêu cầu có Tài khoản Apple" | Máy ảo chưa đăng nhập, hoặc chưa gắn file `.storekit` vào scheme |

### Quảng cáo test không lên

Chạy `isTestMode: true` mà vẫn trống thì gần như chắc chắn là **mạng**: máy ảo không ra được
Internet, hoặc đang qua VPN chặn. Kiểm tra bằng Safari trong chính máy ảo đó.

---

## 14. Tham chiếu API

### AdsConfiguration

| Trường | Mặc định | Nghĩa |
|---|---|---|
| `units` | rỗng | Id thật, theo từng định dạng |
| `appId` | `nil` | Id ứng dụng AdMob, chỉ để đối chiếu với Info.plist |
| `isTestMode` | `false` | Dùng bộ id test của Google, không đụng `units` |
| `isEnabled` | `true` | Công tắc tổng — tắt thì không hỏi cả UMP lẫn ATT |
| `testDeviceIdentifiers` | rỗng | Máy test: quảng cáo thật, click không tính |
| `requestsAppTracking` | `true` | Xin ATT ngay sau khi form đồng ý đóng |
| `bannerSize` | `.adaptive` | `.adaptive` hoặc `.compact` |
| `collapsibleBanner` | `.none` | `.top` · `.bottom` |
| `interstitialPacing` | `.everyTime` | Nhịp mặc định cho mọi vị trí |
| `fullScreenLoadTimeout` | `12` giây | Chờ tối đa bao lâu rồi mở cổng đi tiếp |
| `minimumFullScreenInterval` | `0` | Quãng nghỉ tối thiểu giữa hai quảng cáo toàn màn hình |
| `appOpenExpiration` | `4` giờ | Quảng cáo App Open để lâu thì bỏ, tải mới |
| `showsAppOpenOnForeground` | `true` | Hiện App Open khi quay lại app |
| `loadingText` | `"Loading Ads..."` | Chữ trên màn chờ |

### AdsKit

| Thành viên | Ghi chú |
|---|---|
| `AdsKit.shared` | Điểm vào duy nhất |
| `configure(_:)` | Gọi một lần, sớm nhất có thể |
| `start(from:) async` | `.gsxAds()` tự gọi; gọi tay nếu không dùng modifier |
| `startAndShowLaunchAd(from:) async` | Cho màn splash |
| `configuration` | Sửa được lúc chạy |
| `isReady` | SDK đã khởi động và đã hỏi xong đồng ý |
| `presentation` | `isLoading` · `isPresenting` · `isBusy` |
| `onEvent` | Mọi sự kiện của mọi định dạng |
| `interstitial` · `rewarded` · `rewardedInterstitial` · `appOpen` | Bốn kho quảng cáo toàn màn hình |

### Kho quảng cáo toàn màn hình

| Hàm | Có ở |
|---|---|
| `show(slot:pacing:from:) async -> AdShowResult` | interstitial |
| `show(slot:from:) async -> AdRewardResult` | rewarded, rewardedInterstitial |
| `showOnLaunch(from:) async` · `showIfAvailable(from:) async` · `prepare()` | appOpen |
| `preload(slot:)` · `isReady(slot:)` | tất cả |
| `invalidate(slot:)` · `invalidateAll()` · `resetPacing(slot:)` | tất cả |

### View và modifier

| Tên | Việc |
|---|---|
| `BannerAd(slot:size:collapsible:reservesSpace:)` | Ô banner |
| `NativeAdSlot(slot:style:reservesSpace:)` | Ô native, khuôn dựng sẵn |
| `NativeAdSlot(slot:reservedHeight:content:)` | Ô native, bố cục tự viết |
| `AdsLoadingOverlay()` | Màn chờ, nếu tự dựng thay vì dùng `.gsxAds()` |
| `.gsxAds(appOpenOnForeground:)` | Bật cả tầng quảng cáo |
| `.adsLoadingOverlay()` | Chỉ gắn màn chờ |
| `.preloadInterstitial(slot:)` · `.preloadRewarded(slot:)` | Tải sẵn khi màn hình hiện ra |
| `.nativeAdTheme(_:)` | Giao diện cho các ô native bên trong |

### GSXBilling

| Thành viên | Ghi chú |
|---|---|
| `BillingKit.shared` | |
| `configure(productIds:)` · `start()` | Gọi lúc mở app |
| `plans` · `plan(_:)` · `isLoaded` | Danh sách gói, đúng thứ tự đã khai |
| `purchase(_:) async` · `purchase(productId:) async` | `.bought` · `.cancelled` · `.pending` · `.unavailable` |
| `restore() async -> Bool` | Đọc lại quyền lợi, chỉ hỏi mật khẩu khi cần |
| `refreshEntitlements() async` | Đọc lại mà không hỏi gì |
| `showManageSubscriptions() async` | Mở màn hình quản lý gói của hệ thống |
| `isPurchased` · `isBusy` · `onPurchase` | |
| `PlanCard` · `PurchaseButton` · `PaywallFooter` · `SubscriptionPaywall` | Mảnh dựng sẵn |

### GSXCore

| Thành viên | Ghi chú |
|---|---|
| `EntitlementCenter.shared.isAdsRemoved` | Câu hỏi mọi định dạng đều hỏi trước khi tải |
| `.setPurchased(_:)` | Chỉ lớp thanh toán được gọi |
| `.isAdsRemovedManually` | Gỡ quảng cáo bằng đường khác — thưởng, mã, cờ nội bộ |
| `NetworkMonitor.shared.isConnected` | |
| `GSXLog.isEnabled` | |

### AdError

| Lý do | Là lỗi? | Nên làm gì |
|---|---|---|
| `.notConfigured` | Có | Gọi `configure` trước |
| `.adsDisabled` | Không | Đúng như cấu hình |
| `.noAdUnitId` | Có | Khai id cho định dạng đó |
| `.noNetwork` | Có | Không làm gì được, thử lại sau |
| `.consentNotObtained` | Có | Chờ `.gsxAds()` chạy xong, hoặc người dùng đã từ chối |
| `.sdkNotStarted` | Có | Gọi sớm quá — chờ `AdsKit.shared.isReady` |
| `.purchased` | Không | Người dùng đã trả tiền |
| `.alreadyLoading` · `.alreadyLoaded` · `.alreadyPresenting` | Có | Đang bận, thử lại sau |
| `.pacing` | Không | Chưa tới lượt theo nhịp đã đặt |
| `.tooSoon` | Không | Chưa hết quãng nghỉ |
| `.timedOut` | Có | Mạng chậm hoặc không có hàng để lấp |
| `.noPresenter` | Có | Không tìm được màn hình — gọi lúc app ở nền? |
| `.google(String)` | Có | Nguyên văn lỗi từ Google Mobile Ads |

`error.isFailure` phân biệt sẵn hai nhóm này, để log không kêu ầm lên vì những thứ đang chạy
đúng.

---

## 15. Chạy test

Bộ chính — 47 bài, chạy được ở dòng lệnh:

```bash
xcodebuild test -scheme GSXAdsKit-Package \
  -destination 'platform=iOS Simulator,name=iPhone 17 Pro'
```

| Nhóm | Kiểm những gì |
|---|---|
| `AdGate` | từng lý do chặn, theo đúng thứ tự · đã mua thì chặn trước cả khi hỏi id hay mạng |
| `AdWaterfall` | id hỏng thì thử id sau **ngay trong cùng một lần** · hết id thì báo lỗi cuối |
| `InterstitialPacing` | lần 2, 5, 8… · đếm riêng theo vị trí · số 0 và số âm bị kẹp lại |
| `AdsPresentationState` | không cho hai quảng cáo chồng nhau · quãng nghỉ giữa hai lần |
| `AdsConfiguration` | chế độ test không đụng tới id thật · mọi định dạng đều có id test |
| `EntitlementCenter` | nhớ qua lần mở app sau · hoàn tiền thì quảng cáo quay lại |
| `BillingMath` | loại gói đọc từ chu kỳ · giá quy về tuần · phần trăm tiết kiệm · không chia cho 0 |
| `TrackingAuthorization` | thiếu lý do trong Info.plist thì **không chờ** · không tự đổi trạng thái |
| `READMESnippets` | mọi đoạn mã trong chính tài liệu này đều biên dịch được |

Bộ thứ hai — mua bán thật trên **`SKTestSession`**, cửa hàng giả lập của Xcode. Không phải
mock: StoreKit thật, giao dịch thật, chỉ tiền là không thật.

```
Example/GSXAdsDemo.xcodeproj → ⌘U
```

| Nhóm | Kiểm những gì |
|---|---|
| Tải gói | đúng thứ tự đã khai · id gõ sai không kéo đổ id còn lại · không khai id nào |
| Mua | gói tuần · mua đứt · id không có trong danh sách · Ask to Buy trả `pending` |
| Giao dịch | **được `finish` hẳn** — bỏ sót là App Store gửi lại mỗi lần mở app, mãi mãi |
| Mất quyền lợi | hết hạn · hoàn tiền |
| Khôi phục | máy mới, cùng tài khoản Apple |
| Số liệu | dùng thử miễn phí · giá lấy từ App Store |

> Nhóm này phải chạy **bằng Xcode**. Qua `xcodebuild test` ở dòng lệnh, trên một số máy cửa
> hàng giả lập không dựng lên được — `SKTestSession` khởi tạo xong nhưng không có gói nào,
> kèm `SKInternalErrorDomain Code=3` trong log (kiểm chứng: cả file `.storekit` của một
> project đang chạy tốt cũng ra rỗng, nên đây là môi trường chứ không phải cấu hình). Gặp
> cảnh đó thì cả 17 bài tự bỏ qua thay vì báo đỏ, và bộ 47 bài ở trên vẫn phủ hết phần tính
> toán.

Hai thứ **không** có bài test nào kiểm được, vì cả hai đều đứng chờ một ngón tay: form đồng
ý của UMP và hộp thoại ATT. Cách kiểm là chạy app thử trên máy ảo, xoá app đi để lựa chọn cũ
mất, rồi mở lại — form phải hiện, và bấm xong thì log chạy tiếp tới `Google Mobile Ads đã
start`.

---

## 16. App thử

`Example/GSXAdsDemo.xcodeproj` — mở là chạy được ngay, dùng id test của Google nên không
đụng tới tài khoản AdMob nào. Trong đó có đủ sáu định dạng, cả ba khuôn native dựng sẵn, một
ô native tự viết bố cục, và một tab Billing.

Tab **Billing** chạy trên `Example/Products.storekit` (tuần có 3 ngày dùng thử, năm, trọn
đời) — mua được thật ngay trên máy ảo, không cần App Store Connect và không mất đồng nào.
Mua xong thì mọi ô quảng cáo ở tab kia biến mất ngay, không phải mở lại app.

> Tab Billing chỉ chạy khi **mở bằng Xcode và bấm Run**: file `.storekit` do Xcode nạp vào
> qua scheme, `xcrun simctl launch` không nạp được. Chạy ngoài Xcode thì StoreKit đi hỏi App
> Store thật và sẽ đòi đăng nhập Tài khoản Apple.

Mở thẳng vào một tab:

```bash
xcrun simctl launch booted com.gsx.adskit.demo -startTab billing
```

Chạy ở chế độ test, Google bật sẵn **AdMob native ad validator** — cái bong bóng nổi lên
trên mỗi ô native. Nó phải nói *"No implementation issues found"*; nếu báo lỗi thì bố cục
đang thiếu một thành phần bắt buộc hoặc gắn sai chỗ.

---

## 17. Chuyển từ app UIKit

| Bản UIKit | Ở đây |
|---|---|
| `onAdClosed` gắn vào `UIViewController`, phải dựng `InterstitialRelay` 0×0 | `await interstitial.show(slot:)` |
| `Timer` dò mỗi giây xem quảng cáo tải xong chưa | `async/await`, hiện ngay trong khung hình đó |
| 4 file `.xib` cho native + `viewWithTag` | Bố cục SwiftUI, ba khuôn dựng sẵn |
| `RappleProgressHUD` (4 file) | `AdsLoadingOverlay`, một View |
| `countTier` xoay vòng — id hỏng thì đợi lượt sau | `AdWaterfall` thử hết id trong cùng một lần |
| Sáu file chép lại cùng một bộ điều kiện (hai chỗ thiếu `return`) | `AdGate` — một chỗ |
| `isShowPopupLoadingAds` là biến toàn cục | `AdsPresentationState`, `@MainActor` |
| `AppPreferences.isSub` đọc thẳng `UserDefaults` | `EntitlementCenter`, `@Observable` |
| `AdConfigId.isTest` là hằng phải sửa code | `AdsConfiguration.isTestMode`, đổi lúc chạy được |
| `Entitlements.unlock(from:then:)` | [Mục 10](#10-mở-khoá-bằng-quảng-cáo) |
| `Billing.shared` (StoreKit 2) | `BillingKit.shared` — gần như y hệt |

Việc cần làm khi chuyển một app cũ:

1. Bỏ thư mục `Ads/`, `AdsBridge/`, `Store/Billing.swift`, `RappleProgressHUD/` và 4 file `.xib`.
2. Chuyển id từ `AppConfigConstants.Ads` sang `AdUnits`.
3. Đổi `AppPreferences.shared.isSub` → `EntitlementCenter.shared.isAdsRemoved`.
4. Đổi `isAdsEnabled` → `configuration.isEnabled`, `isUsingCollapsibleBanner` → `configuration.collapsibleBanner`.
5. Những chỗ `AdsHost.shared.interstitialThen(slot:from:then:)` → `await interstitial.show(slot:)`.

---

## 18. Trước khi phát hành

- [ ] `isTestMode = false`, id thật đã điền
- [ ] `GADApplicationIdentifier` khớp với app id thật (SDK sẽ tự báo nếu lệch)
- [ ] `SKAdNetworkItems` đã dán đủ
- [ ] `NSUserTrackingUsageDescription` viết bằng ngôn ngữ người dùng đọc được
- [ ] Màn hình Cài đặt có mục **Tuỳ chọn riêng tư** (xem [mục 3](#3-đồng-ý-att-quyền-riêng-tư))
- [ ] Product id trùng khớp App Store Connect (SDK ghi log những id không tìm thấy)
- [ ] Màn hình bán hàng có đủ Khôi phục · Điều khoản · Riêng tư
- [ ] Ô native có nhãn "Ad" và validator báo sạch
- [ ] `GSXLog.isEnabled` để mặc định (chỉ in ở bản DEBUG)
