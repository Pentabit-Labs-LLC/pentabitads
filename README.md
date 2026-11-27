# Pentabit Ads SDK

[![Latest version](https://img.shields.io/github/v/tag/Pentabit-Labs-LLC/pentabitads?label=latest%20version&color=blue)](https://github.com/Pentabit-Labs-LLC/pentabitads/releases)

Show ads from the Pentabit ad network in your Android and iOS apps. Add the SDK, initialize it once, then **load** and **show** ads.

| Ad format | Class | Where it appears |
|---|---|---|
| Banner | `PentabitBannerView` | Inside your screen (XML, Compose, UIKit, SwiftUI) |
| Interstitial | `InterstitialAd` | Full screen, between screens |
| Rewarded | `RewardedAd` | Full screen, user earns a reward |
| App open | `AppOpenAd` | Full screen when the app opens |
| Native | `NativeAdLoader` / `NativeAd`, `PentabitNativeAdView` (Android) | Your layout inside a native ad view, like AdMob |
| Icon | `NativeAdLoader` / `NativeAd`, `PentabitIconAdView` (Android) | An icon tile with size and animation |

Requirements: Android 7.0+ (API 24) or iOS 14+. You need an **app key** and **ad unit IDs** from the Pentabit team. An ad unit ID (like `aks-xxxxxxxxxxx-xxx`, created in the portal under Ad units) names one ad slot in your app (for example the banner at the bottom of your home screen).

## Installation at a glance

The SDK is hosted on a plain public Maven repository and a CocoaPod. No token or login is needed. Replace `LATEST_VERSION` with the newest version on the [Releases page](https://github.com/Pentabit-Labs-LLC/pentabitads/releases) (or the badge above) (versions look like `0.1.0.0`).

| Your app | How to add it | Guide |
|---|---|---|
| Kotlin Multiplatform (Android + iOS) | Maven repository, dependencies in `commonMain` | [KMM](#kmm-kotlin-multiplatform) |
| Android (Kotlin/Java) | Maven repository, normal `dependencies {}` | [Android](#android-native) |
| iOS (Swift) | CocoaPod `PentabitAds`, or add the XCFrameworks by hand | [iOS](#ios-native) |

Every setup needs the same three modules at the same version: `pentabit-ads`, `pentabit-ads-video` and `pentabit-analytics`. Then you initialize once and load ads. The [CHANGELOG](CHANGELOG.md) lists what changed in each version.

**Contents:** [KMM](#kmm-kotlin-multiplatform) · [Android (Native)](#android-native) · [iOS (Native)](#ios-native) · [Consent and apps for children](#consent-and-apps-for-children) · [Errors](#errors) · [Testing](#testing) · [Best practices](#best-practices) · [Pentabit Analytics (action reporting)](#pentabit-analytics-action-reporting)

---

## KMM (Kotlin Multiplatform)

Write your ad code once in `commonMain` and run it on Android and iOS. The listeners, load and show calls and revenue callbacks are the same as on Android (see "Android (Native)" for what each callback means). The parts that touch the screen (the host for full-screen ads, the banner view, decoding images) are small `expect`/`actual` helpers that you write once and reuse. The UI examples use Compose Multiplatform.

All listeners are optional: override only what you need. Imports used below: `com.pentabitlabs.pentabitads.ads.*` and `com.pentabitlabs.pentabitads.core.error.AdError`.

### Add the repository

The SDK is a plain Maven repository served over HTTPS. No token or login. Add it once to `settings.gradle.kts` (Android and KMM):

```kotlin
dependencyResolutionManagement {
    repositories {
        maven("https://pentabit-labs-llc.github.io/pentabitads/maven-repo")
    }
}
```

Replace `LATEST_VERSION` below with the newest version, for example `0.1.0.0` (see the [version list](https://pentabit-labs-llc.github.io/pentabitads/maven-repo/com/pentabitlabs/pentabitads/pentabit-ads/maven-metadata.xml)). Versions have four parts, `Major.Minor.Patch.Build`. The running SDK reports its version as `PentabitVersion.VERSION`.

### Add the SDK

```kotlin
// shared/build.gradle.kts
kotlin {
    sourceSets {
        commonMain.dependencies {
            implementation("com.pentabitlabs.pentabitads:pentabit-ads:LATEST_VERSION")
            implementation("com.pentabitlabs.pentabitads:pentabit-ads-video:LATEST_VERSION") // required: interstitial and rewarded ads are often video
            implementation("com.pentabitlabs.pentabitads:pentabit-analytics:LATEST_VERSION") // required: action reporting, started by PentabitAds.initialize
        }
    }
}
```

### Initialize once

`PentabitAds.initialize` takes a `PlatformContext`, which each platform creates differently. Hide it behind an `expect` function:

```kotlin
// commonMain
expect fun platformContext(): PlatformContext

fun initAds() {
    PentabitAdsVideo.install()   // required, call before initialize (video ads need it)
    PentabitAds.initialize(
        platformContext(),
        PentabitAdsOptions(appKey = "YOUR_APP_KEY", audience = AudienceProfile.GENERAL, debug = isDebugBuild),
    )
}

// androidMain (call initAds() from Application.onCreate; keep the application context)
lateinit var appContext: Context
actual fun platformContext() = PlatformContext(appContext)

// iosMain (call initAds() from your App init)
actual fun platformContext() = PlatformContext()
```

### Platform helpers (write once)

Full-screen ads need an `AdHost`: the current `Activity` on Android and the current `UIViewController` on iOS. Image assets of native and icon ads are files that you decode on each platform.

```kotlin
// commonMain
@Composable expect fun rememberAdHost(): AdHost
expect fun decodeImage(path: String): ImageBitmap?

// androidMain
@Composable actual fun rememberAdHost(): AdHost = LocalContext.current as Activity
actual fun decodeImage(path: String): ImageBitmap? = BitmapFactory.decodeFile(path)?.asImageBitmap()

// iosMain
@Composable actual fun rememberAdHost(): AdHost = LocalUIViewController.current
@OptIn(ExperimentalForeignApi::class)
actual fun decodeImage(path: String): ImageBitmap? {
    val data = NSData.dataWithContentsOfFile(path) ?: return null
    val bytes = ByteArray(data.length.toInt())
    bytes.usePinned { memcpy(it.addressOf(0), data.bytes, data.length) }
    return Image.makeFromEncoded(bytes).toComposeImageBitmap()   // org.jetbrains.skia.Image
}
```

### Report in-app actions (required)

Action reporting comes with the Ads SDK. `PentabitAds.initialize` starts it with the same app key, audience, debug setting and consent, so you make no extra initialize call (the `pentabit-analytics` dependency is listed in "Add the SDK" above). Installs and retention (days 1, 3, 7, 14 and 30) are reported automatically. Report the actions only your app knows; advertisers are billed on these actions, now and when the network runs paid campaigns:

```kotlin
PentabitAnalytics.trackRegistration()
PentabitAnalytics.trackLevelReached(10)
PentabitAnalytics.trackPurchase(revenue = 4.99, currency = "USD", productId = "gems_100")
PentabitAnalytics.trackSubscribe(revenue = 9.99, currency = "USD", productId = "pro_monthly")
```

Full list and options: see "Pentabit Analytics" below.

### Revenue callbacks (all formats)

Every format reports the same two callbacks:

| Callback | When |
|---|---|
| `onAdImpression()` | The ad was counted as an impression. Once per ad. |
| `onAdPaid(value: AdValue)` | Right after the impression, with what it earned: `value.valueMicros` (millionths of `value.currencyCode`, so 1_000_000 = 1 USD) and `value.currencyCode`. The backend sends the amount with the ad. It is `0` USD while only cross-promotion is served. |

Banner uses `BannerListener`, interstitial / rewarded / app open use `AdShowListener`, native and icon use `NativeAdEventListener`. Each format below shows it.

### Interstitial

#### Load

```kotlin
// commonMain
class InterstitialController(adUnitId: String) {
    private val ad = PentabitAds.interstitial(adUnitId)

    fun load() = ad.load(object : AdLoadListener() {
        override fun onLoaded() { }                       // ready to show
        override fun onLoadFailed(error: AdError) { }     // error.code and error.message say why
    })
    // the class continues under "Show"
```

Load early (for example when the screen starts). `ad.isReady` tells you if it can be shown.

#### Show

```kotlin
    fun show(host: AdHost, onDone: () -> Unit) {
        if (!ad.isReady) return onDone()
        ad.show(host, object : AdShowListener() {
            override fun onShown() { }                    // the ad is on screen
            override fun onClicked() { }                  // the user tapped the ad
            override fun onClosed() { load(); onDone() }  // preload the next one, then go on
            override fun onShowFailed(error: AdError) = onDone()
        })
    }
}

// usage in Compose
val host = rememberAdHost()
val interstitial = remember { InterstitialController("aks-xxxxxxxxxxx-xxx").also { it.load() } }
Button(onClick = { interstitial.show(host) { goToNextScreen() } }) { Text("Next") }
```

#### Revenue reporting

Add the two callbacks to the `AdShowListener` you pass to `show`:

```kotlin
override fun onAdImpression() { }
override fun onAdPaid(value: AdValue) {
    logRevenue(value.valueMicros / 1_000_000.0, value.currencyCode)   // your analytics call
}
```

### Rewarded

#### Load

```kotlin
// commonMain
class RewardedController(adUnitId: String) {
    private val ad = PentabitAds.rewarded(adUnitId)
    var ready by mutableStateOf(false)
        private set

    fun load() = ad.load(object : AdLoadListener() {
        override fun onLoaded() { ready = true }
        override fun onLoadFailed(error: AdError) { ready = false }
    })
    // the class continues under "Show"
```

#### Show

```kotlin
    fun show(host: AdHost, onReward: (RewardItem) -> Unit) {
        if (!ad.isReady) return
        ad.show(host, object : AdShowListener() {
            override fun onShown() { }
            override fun onClicked() { }
            override fun onRewardEarned(reward: RewardItem) { onReward(reward) }   // grant the reward here, and only here
            override fun onClosed() { ready = false; load() }
            override fun onShowFailed(error: AdError) { load() }
        })
    }
}

// usage in Compose
val host = rememberAdHost()
val rewarded = remember { RewardedController("aks-xxxxxxxxxxx-xxx").also { it.load() } }
Button(enabled = rewarded.ready, onClick = { rewarded.show(host) { giveLives(it.amount) } }) { Text("Watch for a life") }
```

`onRewardEarned` can arrive slightly after `onClosed`. `reward.type` and `reward.amount` are the values you set on the ad unit in the portal.

#### Revenue reporting

```kotlin
override fun onAdImpression() { }
override fun onAdPaid(value: AdValue) {
    logRevenue(value.valueMicros / 1_000_000.0, value.currencyCode)
}
```

### App open

#### Load

```kotlin
// commonMain
class AppOpenController(adUnitId: String) {
    private val ad = PentabitAds.appOpen(adUnitId)

    fun load() = ad.load(object : AdLoadListener() {
        override fun onLoaded() { }
        override fun onLoadFailed(error: AdError) { }
    })
    // the class continues under "Show"
```

#### Show

```kotlin
    // call when the app returns to the foreground (ProcessLifecycleOwner on Android,
    // UIApplication.willEnterForegroundNotification on iOS)
    fun showIfReady(host: AdHost) {
        if (!ad.isReady) return
        ad.show(host, object : AdShowListener() {
            override fun onShown() { }
            override fun onClicked() { }
            override fun onClosed() { load() }            // preload the next one
            override fun onShowFailed(error: AdError) { load() }
        })
    }
}
```

#### Revenue reporting

```kotlin
override fun onAdImpression() { }
override fun onAdPaid(value: AdValue) {
    logRevenue(value.valueMicros / 1_000_000.0, value.currencyCode)
}
```

### Banner

The banner is a native view on each platform, wrapped once in a composable.

**Banner sizes.** Set the size before `load`. The server returns a banner of exactly that size, or no ad (`NO_FILL`); it never stretches a banner of another size.

| Size | `adSize` | Dp |
|---|---|---|
| Banner | `BannerSize.BANNER` (default) | 320x50 |
| Large banner | `BannerSize.LARGE_BANNER` | 320x100 |
| Medium rectangle | `BannerSize.MEDIUM_RECTANGLE` | 300x250 |

```kotlin
binding.banner.adSize = BannerSize.LARGE_BANNER   // before load
```


#### Load and show

```kotlin
// commonMain
@Composable
expect fun PentabitBanner(adUnitId: String, modifier: Modifier = Modifier, listener: BannerListener = BannerListener())

// androidMain
@Composable
actual fun PentabitBanner(adUnitId: String, modifier: Modifier, listener: BannerListener) {
    val context = LocalContext.current
    val banner = remember { PentabitBannerView(context) }
    DisposableEffect(banner) { onDispose { banner.destroy() } }
    AndroidView(modifier = modifier.fillMaxWidth(), factory = { banner })
    LaunchedEffect(adUnitId) { banner.load(adUnitId, listener) }
}

// iosMain
@OptIn(ExperimentalForeignApi::class)
@Composable
actual fun PentabitBanner(adUnitId: String, modifier: Modifier, listener: BannerListener) {
    UIKitView(
        factory = { PentabitBannerView(frame = CGRectMake(0.0, 0.0, 320.0, 50.0)).also { it.load(adUnitId, listener) } },
        modifier = modifier.fillMaxWidth().height(50.dp),
        onRelease = { it.destroy() },
    )
}

// usage in shared UI
PentabitBanner("aks-xxxxxxxxxxx-xxx", listener = object : BannerListener() {
    override fun onLoaded() { }
    override fun onLoadFailed(error: AdError) { }
    override fun onShown() { }
    override fun onClicked() { }
})
```

A banner does not refresh by itself. Call `load` again when you want a new ad, no more often than every 30 seconds.

#### Revenue reporting

Add the two callbacks to the `BannerListener` you pass to the composable:

```kotlin
override fun onAdImpression() { }
override fun onAdPaid(value: AdValue) {
    logRevenue(value.valueMicros / 1_000_000.0, value.currencyCode)
}
```

### Native

In KMM you draw the native ad in shared Compose code from the assets of the ad. You must show the "Ad" label and an (i) button that calls `openPrivacyPolicy()`, and you report the impression and clicks.

#### Load

```kotlin
// commonMain
@Composable
fun PentabitNative(adUnitId: String, modifier: Modifier = Modifier, listener: NativeAdEventListener? = null) {
    var nativeAd by remember(adUnitId) { mutableStateOf<NativeAd?>(null) }
    DisposableEffect(adUnitId) {
        var loaded: NativeAd? = null
        PentabitAds.nativeAds(adUnitId).load(object : NativeAdListener() {
            override fun onLoaded(ad: NativeAd) {
                ad.setEventListener(listener)     // before recordImpression
                loaded = ad
                nativeAd = ad
            }
            override fun onLoadFailed(error: AdError) { }
        })
        onDispose { loaded?.destroy() }           // free the ad when it leaves the screen
    }
    nativeAd?.let { NativeCard(it, modifier) }
}
```

#### Show

```kotlin
@Composable
private fun NativeCard(ad: NativeAd, modifier: Modifier) {
    val icon = remember(ad) { ad.iconPath?.let { decodeImage(it) } }
    val image = remember(ad) { ad.imagePath?.let { decodeImage(it) } }
    LaunchedEffect(ad) { ad.recordImpression() }   // the card is on screen: count the impression

    Box(modifier.background(Color.White, RoundedCornerShape(16.dp))) {
        Column(Modifier.padding(12.dp)) {
            Row(verticalAlignment = Alignment.CenterVertically) {
                icon?.let { Image(it, null, Modifier.size(44.dp).clip(RoundedCornerShape(10.dp)).clickable { ad.recordClick() }) }
                Text(ad.title ?: "", Modifier.padding(start = 10.dp, end = 48.dp).clickable { ad.recordClick() }, fontWeight = FontWeight.Bold, maxLines = 1)
            }
            image?.let { Image(it, null, Modifier.fillMaxWidth().padding(top = 10.dp).clip(RoundedCornerShape(12.dp)).clickable { ad.recordClick() }, contentScale = ContentScale.Crop) }
            ad.body?.let { Text(it, Modifier.padding(top = 10.dp)) }
            Button(onClick = { ad.recordClick() }, modifier = Modifier.fillMaxWidth().padding(top = 12.dp)) { Text(ad.callToAction ?: "Open") }
        }
        // "Ad" tag and (i) button, top right (required)
        Row(Modifier.align(Alignment.TopEnd).padding(top = 2.dp, end = 2.dp), verticalAlignment = Alignment.CenterVertically) {
            Text(ad.sponsoredLabel, Modifier.background(Color(0xFFFBC02D), RoundedCornerShape(3.dp)).padding(horizontal = 4.dp), color = Color.White, fontSize = 9.sp, fontWeight = FontWeight.Bold)
            Box(Modifier.size(28.dp).clickable { ad.openPrivacyPolicy() }, contentAlignment = Alignment.Center) {
                Box(Modifier.size(11.dp).border(1.dp, Color(0xFF00AEEF), CircleShape), contentAlignment = Alignment.Center) {
                    Text("i", color = Color(0xFF00AEEF), fontSize = 7.sp, fontWeight = FontWeight.Bold)
                }
            }
        }
    }
}

// usage in shared UI
PentabitNative("aks-xxxxxxxxxxx-xxx", Modifier.fillMaxWidth())
```

#### Revenue reporting

Pass a `NativeAdEventListener` as `listener`:

```kotlin
PentabitNative("aks-xxxxxxxxxxx-xxx", listener = object : NativeAdEventListener() {
    override fun onAdImpression() { }
    override fun onAdPaid(value: AdValue) {
        logRevenue(value.valueMicros / 1_000_000.0, value.currencyCode)
    }
    override fun onClicked() { }
})
```

### Icon

The advertised app's icon in a small tile, with the "Ad" tag, the (i) button and an optional animation.

#### Load

```kotlin
// commonMain
enum class IconAnimation { None, Pulse, Bounce, Wiggle, Rotate }

@Composable
fun PentabitIconAd(
    adUnitId: String,
    size: Dp = 96.dp,                              // 64.dp, 96.dp or 128.dp like the Android icon ad sizes
    animation: IconAnimation = IconAnimation.Pulse,
    listener: NativeAdEventListener? = null,
) {
    var iconAd by remember(adUnitId) { mutableStateOf<NativeAd?>(null) }
    DisposableEffect(adUnitId) {
        var loaded: NativeAd? = null
        PentabitAds.iconAds(adUnitId).load(object : NativeAdListener() {
            override fun onLoaded(ad: NativeAd) {
                ad.setEventListener(listener)     // before recordImpression
                loaded = ad
                iconAd = ad
            }
            override fun onLoadFailed(error: AdError) { }
        })
        onDispose { loaded?.destroy() }
    }
    iconAd?.let { IconTile(it, size, animation) }
}
```

#### Show

```kotlin
@Composable
private fun IconTile(ad: NativeAd, size: Dp, animation: IconAnimation) {
    val icon = remember(ad) { ad.iconPath?.let { decodeImage(it) } }
    LaunchedEffect(ad) { ad.recordImpression() }

    val t = rememberInfiniteTransition()
    val pulse by t.animateFloat(1f, 1.15f, infiniteRepeatable(tween(600), RepeatMode.Reverse))
    val bounce by t.animateFloat(0f, -0.11f, infiniteRepeatable(tween(600), RepeatMode.Reverse))
    val wiggle by t.animateFloat(-10f, 10f, infiniteRepeatable(tween(150), RepeatMode.Reverse))
    val spin by t.animateFloat(0f, 360f, infiniteRepeatable(tween(1200, easing = LinearEasing)))

    Box(Modifier.size(size)) {
        icon?.let {
            Image(it, "Sponsored app icon", Modifier.align(Alignment.Center).size(size * 0.77f)
                .graphicsLayer {
                    when (animation) {
                        IconAnimation.Pulse -> { scaleX = pulse; scaleY = pulse }
                        IconAnimation.Bounce -> translationY = bounce * size.toPx()
                        IconAnimation.Wiggle -> rotationZ = wiggle
                        IconAnimation.Rotate -> rotationZ = spin
                        IconAnimation.None -> {}
                    }
                }
                .clickable { ad.recordClick() })
        }
        Text(ad.sponsoredLabel, Modifier.align(Alignment.TopEnd).padding(top = 3.dp, end = 3.dp).background(Color(0xFFFBC02D), RoundedCornerShape(3.dp)).padding(horizontal = 4.dp), color = Color.White, fontSize = 9.sp, fontWeight = FontWeight.Bold)
        Box(Modifier.align(Alignment.BottomStart).size(28.dp).clickable { ad.openPrivacyPolicy() }, contentAlignment = Alignment.Center) {
            Box(Modifier.size(11.dp).border(1.dp, Color(0xFF00AEEF), CircleShape), contentAlignment = Alignment.Center) {
                Text("i", color = Color(0xFF00AEEF), fontSize = 7.sp, fontWeight = FontWeight.Bold)
            }
        }
    }
}

// usage in shared UI
PentabitIconAd("aks-xxxxxxxxxxx-xxx", size = 64.dp, animation = IconAnimation.Bounce)
```

#### Revenue reporting

Same as native: pass a `NativeAdEventListener` as `listener`:

```kotlin
PentabitIconAd("aks-xxxxxxxxxxx-xxx", listener = object : NativeAdEventListener() {
    override fun onAdImpression() { }
    override fun onAdPaid(value: AdValue) {
        logRevenue(value.valueMicros / 1_000_000.0, value.currencyCode)
    }
    override fun onClicked() { }
})
```

---

## Android (Native)

Imports used below: `com.pentabitlabs.pentabitads.ads.*` and `com.pentabitlabs.pentabitads.core.error.AdError`. All listeners are optional: override only what you need.

### Add the SDK

Add the Maven repository from the KMM section above to `settings.gradle.kts` first.

```kotlin
// app/build.gradle.kts
dependencies {
    implementation("com.pentabitlabs.pentabitads:pentabit-ads:LATEST_VERSION")
    implementation("com.pentabitlabs.pentabitads:pentabit-ads-video:LATEST_VERSION") // required: interstitial and rewarded ads are often video
    implementation("com.pentabitlabs.pentabitads:pentabit-analytics:LATEST_VERSION") // required: action reporting, started by PentabitAds.initialize
}
```

You do not need to edit your manifest or ProGuard rules.

### Initialize once

```kotlin
class MyApp : Application() {
    override fun onCreate() {
        super.onCreate()
        PentabitAdsVideo.install()   // required, call before initialize (video ads need it)
        PentabitAds.initialize(
            this,
            PentabitAdsOptions(
                appKey = "YOUR_APP_KEY",
                audience = AudienceProfile.GENERAL,   // use CHILD_DIRECTED for apps for children
                debug = BuildConfig.DEBUG,            // debug builds show Pentabit test ads
            ),
        )
    }
}
```

`initialize` returns immediately and never throws.

### Report in-app actions (required)

Action reporting comes with the Ads SDK. `PentabitAds.initialize` starts it with the same app key, audience, debug setting and consent, so you make no extra initialize call (the `pentabit-analytics` dependency is listed in "Add the SDK" above). Installs and retention (days 1, 3, 7, 14 and 30) are reported automatically. Report the actions only your app knows; advertisers are billed on these actions, now and when the network runs paid campaigns:

```kotlin
PentabitAnalytics.trackRegistration()
PentabitAnalytics.trackLevelReached(10)
PentabitAnalytics.trackPurchase(revenue = 4.99, currency = "USD", productId = "gems_100")
PentabitAnalytics.trackSubscribe(revenue = 9.99, currency = "USD", productId = "pro_monthly")
```

Full list and options: see "Pentabit Analytics" below.

### Revenue callbacks (all formats)

Every format reports the same two callbacks, like AdMob's `onAdImpression` and paid event:

| Callback | When |
|---|---|
| `onAdImpression()` | The ad was counted as an impression. Once per ad. |
| `onAdPaid(value: AdValue)` | Right after the impression, with what it earned: `value.valueMicros` (millionths of `value.currencyCode`, so 1_000_000 = 1 USD) and `value.currencyCode`. The backend sends the amount with the ad. It is `0` USD while only cross-promotion is served. |

Which listener carries them: banner uses `BannerListener`, interstitial / rewarded / app open use `AdShowListener`, native and icon use `NativeAdEventListener`. Each format below shows it.

### Interstitial

A full-screen ad between screens.

#### Load

```kotlin
private val interstitial = PentabitAds.interstitial("aks-xxxxxxxxxxx-xxx")

interstitial.load(object : AdLoadListener() {
    override fun onLoaded() { }                       // ready to show
    override fun onLoadFailed(error: AdError) { }     // error.code and error.message say why
})
```

Load early (for example when the screen starts) so the ad is ready at the break. `interstitial.isReady` tells you if it can be shown.

#### Show

```kotlin
if (interstitial.isReady) {
    interstitial.show(this /* Activity */, object : AdShowListener() {
        override fun onShown() { }                    // the ad is on screen
        override fun onClicked() { }                  // the user tapped the ad
        override fun onClosed() {                     // the user closed it
            interstitial.load()                       // preload the next one
            goToNextScreen()
        }
        override fun onShowFailed(error: AdError) = goToNextScreen()
    })
} else {
    goToNextScreen()
}
```

#### Revenue reporting

Add the two revenue callbacks to the same `AdShowListener` you pass to `show`:

```kotlin
override fun onAdImpression() { }
override fun onAdPaid(value: AdValue) {
    analytics.logAdRevenue(value.valueMicros / 1_000_000.0, value.currencyCode)
}
```

### Rewarded

A full-screen ad the user watches to earn a reward.

#### Load

```kotlin
private val rewarded = PentabitAds.rewarded("aks-xxxxxxxxxxx-xxx")

rewarded.load(object : AdLoadListener() {
    override fun onLoaded() { watchButton.isEnabled = true }
    override fun onLoadFailed(error: AdError) { watchButton.isEnabled = false }
})
```

#### Show

```kotlin
watchButton.setOnClickListener {
    rewarded.show(this /* Activity */, object : AdShowListener() {
        override fun onShown() { }
        override fun onClicked() { }
        override fun onRewardEarned(reward: RewardItem) {
            giveLives(reward.amount)                  // grant the reward here, and only here
        }
        override fun onClosed() { rewarded.load() }
        override fun onShowFailed(error: AdError) { toast("No ad available, try later") }
    })
}
```

`onRewardEarned` can arrive slightly after `onClosed`. Grant the reward only when it is called. `reward.type` and `reward.amount` are the values you set on the ad unit in the portal.

#### Revenue reporting

Same two callbacks on the `AdShowListener` you pass to `show`:

```kotlin
override fun onAdImpression() { }
override fun onAdPaid(value: AdValue) {
    analytics.logAdRevenue(value.valueMicros / 1_000_000.0, value.currencyCode)
}
```

### App open

A full-screen ad shown when the app opens or returns to the foreground.

#### Load

```kotlin
private val appOpen = PentabitAds.appOpen("aks-xxxxxxxxxxx-xxx")

appOpen.load(object : AdLoadListener() {
    override fun onLoaded() { }
    override fun onLoadFailed(error: AdError) { }
})
```

#### Show

```kotlin
// when the app returns to the foreground (for example from ProcessLifecycleOwner's onStart):
if (appOpen.isReady) {
    appOpen.show(activity, object : AdShowListener() {
        override fun onShown() { }
        override fun onClicked() { }
        override fun onClosed() { appOpen.load() }    // preload the next one
        override fun onShowFailed(error: AdError) { appOpen.load() }
    })
}
```

#### Revenue reporting

```kotlin
override fun onAdImpression() { }
override fun onAdPaid(value: AdValue) {
    analytics.logAdRevenue(value.valueMicros / 1_000_000.0, value.currencyCode)
}
```

### Banner

An ad inside your screen. It is a view: use it in XML or in Compose.

**Banner sizes.** Set the size before `load`. The server returns a banner of exactly that size, or no ad (`NO_FILL`); it never stretches a banner of another size.

| Size | `adSize` | Dp |
|---|---|---|
| Banner | `BannerSize.BANNER` (default) | 320x50 |
| Large banner | `BannerSize.LARGE_BANNER` | 320x100 |
| Medium rectangle | `BannerSize.MEDIUM_RECTANGLE` | 300x250 |

```kotlin
binding.banner.adSize = BannerSize.LARGE_BANNER   // before load
```


#### Load and show (XML)

```xml
<com.pentabitlabs.pentabitads.ads.PentabitBannerView
    android:id="@+id/banner"
    android:layout_width="match_parent"
    android:layout_height="wrap_content" />
```

```kotlin
binding.banner.load("aks-xxxxxxxxxxx-xxx", object : BannerListener() {
    override fun onLoaded() { }                       // the banner is ready and is shown
    override fun onLoadFailed(error: AdError) { binding.banner.visibility = View.GONE }
    override fun onShown() { }
    override fun onClicked() { }
})

override fun onDestroy() {
    binding.banner.destroy()
    super.onDestroy()
}
```

A banner does not refresh by itself. Call `load` again when you want a new ad, no more often than every 30 seconds.

#### Load and show (Jetpack Compose)

Wrap the view in `AndroidView`:

```kotlin
@Composable
fun PentabitBanner(adUnitId: String, modifier: Modifier = Modifier, listener: BannerListener = BannerListener()) {
    val context = LocalContext.current
    val banner = remember { PentabitBannerView(context) }
    DisposableEffect(banner) { onDispose { banner.destroy() } }
    AndroidView(modifier = modifier.fillMaxWidth(), factory = { banner })
    LaunchedEffect(adUnitId) { banner.load(adUnitId, listener) }
}

// usage
PentabitBanner("aks-xxxxxxxxxxx-xxx", listener = object : BannerListener() {
    override fun onLoadFailed(error: AdError) { }
})
```

#### Revenue reporting

Add the two callbacks to the same `BannerListener` (XML or Compose):

```kotlin
override fun onAdImpression() { }
override fun onAdPaid(value: AdValue) {
    analytics.logAdRevenue(value.valueMicros / 1_000_000.0, value.currencyCode)
}
```

### Native

An ad you lay out yourself. Like AdMob's `NativeAdView`: put your views inside a `PentabitNativeAdView`, tell it which view shows which asset, then hand it the ad.

#### Load

```kotlin
private var nativeAd: NativeAd? = null

PentabitAds.nativeAds("aks-xxxxxxxxxxx-xxx").load(object : NativeAdListener() {
    override fun onLoaded(ad: NativeAd) {
        nativeAd?.destroy()                           // free the previous ad
        nativeAd = ad
        showNative(ad)                                // see "Show" below
    }
    override fun onLoadFailed(error: AdError) { }
})
```

#### Show (XML)

```xml
<!-- res/layout/native_ad_layout.xml -->
<com.pentabitlabs.pentabitads.ads.PentabitNativeAdView
    xmlns:android="http://schemas.android.com/apk/res/android"
    android:id="@+id/nativeAdView"
    android:layout_width="match_parent"
    android:layout_height="wrap_content">

    <LinearLayout android:layout_width="match_parent" android:layout_height="wrap_content"
        android:orientation="vertical" android:padding="12dp">
        <ImageView android:id="@+id/adIcon" android:layout_width="40dp" android:layout_height="40dp" />
        <TextView  android:id="@+id/adHeadline" android:layout_width="match_parent" android:layout_height="wrap_content" />
        <ImageView android:id="@+id/adMedia" android:layout_width="match_parent" android:layout_height="180dp"
            android:scaleType="centerCrop" />
        <TextView  android:id="@+id/adBody" android:layout_width="match_parent" android:layout_height="wrap_content" />
        <Button    android:id="@+id/adCta" android:layout_width="match_parent" android:layout_height="wrap_content" />
    </LinearLayout>
</com.pentabitlabs.pentabitads.ads.PentabitNativeAdView>
```

```kotlin
fun showNative(ad: NativeAd) {
    val view = binding.nativeAdView
    view.headlineView = binding.adHeadline
    view.bodyView = binding.adBody
    view.callToActionView = binding.adCta
    view.iconView = binding.adIcon                    // an ImageView
    view.mediaView = binding.adMedia                  // an ImageView (the main image)
    view.setNativeAd(ad)                              // fills the views and starts tracking
}

override fun onDestroy() {
    binding.nativeAdView.destroy()
    nativeAd?.destroy()
    super.onDestroy()
}
```

`setNativeAd` does the rest, like AdMob does: it fills each registered view and hides the ones the ad has no asset for; it counts the impression once the ad is on screen; a tap on any registered view records the click and opens the advertiser's page; and it draws the yellow **Ad** tag and the **(i)** privacy button in the top-right corner (leave room for them). You do not call `recordImpression()` or `recordClick()` yourself.

#### Show (Jetpack Compose)

Reuse the XML layout above inside `AndroidView`:

```kotlin
@Composable
fun PentabitNative(adUnitId: String, modifier: Modifier = Modifier, listener: NativeAdEventListener? = null) {
    var nativeAd by remember(adUnitId) { mutableStateOf<NativeAd?>(null) }
    DisposableEffect(adUnitId) {
        var loaded: NativeAd? = null
        PentabitAds.nativeAds(adUnitId).load(object : NativeAdListener() {
            override fun onLoaded(ad: NativeAd) { loaded = ad; nativeAd = ad }
        })
        onDispose { loaded?.destroy() }
    }
    nativeAd?.let { ad ->
        key(ad) {
            AndroidView(modifier = modifier, factory = { ctx ->
                val view = LayoutInflater.from(ctx).inflate(R.layout.native_ad_layout, null) as PentabitNativeAdView
                view.headlineView = view.findViewById(R.id.adHeadline)
                view.bodyView = view.findViewById(R.id.adBody)
                view.callToActionView = view.findViewById(R.id.adCta)
                view.iconView = view.findViewById(R.id.adIcon)
                view.mediaView = view.findViewById(R.id.adMedia)
                ad.setEventListener(listener)         // before setNativeAd
                view.setNativeAd(ad)
                view
            }, onRelease = { it.destroy() })
        }
    }
}

// usage
PentabitNative("aks-xxxxxxxxxxx-xxx")
```

#### Revenue reporting

Set a `NativeAdEventListener` on the ad **before** `setNativeAd` (XML) or pass it as `listener` (Compose):

```kotlin
ad.setEventListener(object : NativeAdEventListener() {
    override fun onAdImpression() { }
    override fun onAdPaid(value: AdValue) {
        analytics.logAdRevenue(value.valueMicros / 1_000_000.0, value.currencyCode)
    }
    override fun onClicked() { }
})
view.setNativeAd(ad)
```

### Icon

The advertised app's icon in a small tile with an "Ad" tag, an (i) button and an optional animation.

#### Load

```kotlin
private var iconAd: NativeAd? = null

PentabitAds.iconAds("aks-xxxxxxxxxxx-xxx").load(object : NativeAdListener() {
    override fun onLoaded(ad: NativeAd) {
        iconAd?.destroy()
        iconAd = ad
        showIcon(ad)                                  // see "Show" below
    }
    override fun onLoadFailed(error: AdError) { }
})
```

#### Show (XML)

```xml
<com.pentabitlabs.pentabitads.ads.PentabitIconAdView
    android:id="@+id/iconAdView"
    android:layout_width="wrap_content"
    android:layout_height="wrap_content" />
```

```kotlin
fun showIcon(ad: NativeAd) {
    binding.iconAdView.adSize = IconAdSize.MEDIUM          // SMALL 64 dp, MEDIUM 96 dp, LARGE 128 dp
    binding.iconAdView.animation = IconAdAnimation.PULSE   // NONE, SHAKE, WIGGLE, BOUNCE, ROTATE, PULSE
    binding.iconAdView.setNativeAd(ad)
}

override fun onDestroy() {
    binding.iconAdView.destroy()
    iconAd?.destroy()
    super.onDestroy()
}
```

Set `adSize`, `animation` and the event listener before `setNativeAd`. The animation is one short burst, a pause (`animationDelaySeconds`, default 3) and repeat; set `animateOnce = true` to play it once. The view draws the **Ad** tag (top-right) and the **(i)** button (bottom-left), counts the impression when it is on screen, and a tap opens the advertiser's page.

#### Show (Jetpack Compose)

```kotlin
@Composable
fun PentabitIconAd(
    adUnitId: String,
    size: IconAdSize = IconAdSize.MEDIUM,
    animation: IconAdAnimation = IconAdAnimation.PULSE,
    listener: NativeAdEventListener? = null,
) {
    var iconAd by remember(adUnitId) { mutableStateOf<NativeAd?>(null) }
    DisposableEffect(adUnitId) {
        var loaded: NativeAd? = null
        PentabitAds.iconAds(adUnitId).load(object : NativeAdListener() {
            override fun onLoaded(ad: NativeAd) { loaded = ad; iconAd = ad }
        })
        onDispose { loaded?.destroy() }
    }
    iconAd?.let { ad ->
        key(ad) {
            AndroidView(factory = { ctx ->
                PentabitIconAdView(ctx).apply {
                    adSize = size
                    this.animation = animation
                    ad.setEventListener(listener)     // before setNativeAd
                    setNativeAd(ad)
                }
            }, onRelease = { it.destroy() })
        }
    }
}

// usage
PentabitIconAd("aks-xxxxxxxxxxx-xxx", size = IconAdSize.SMALL, animation = IconAdAnimation.BOUNCE)
```

#### Revenue reporting

Same listener as native: set a `NativeAdEventListener` on the ad before `setNativeAd`, or pass `listener` to the Compose function:

```kotlin
ad.setEventListener(object : NativeAdEventListener() {
    override fun onAdImpression() { }
    override fun onAdPaid(value: AdValue) {
        analytics.logAdRevenue(value.valueMicros / 1_000_000.0, value.currencyCode)
    }
    override fun onClicked() { }
})
```

---

## iOS (Native)

Listeners are classes: subclass them and override what you need. Swift has no default arguments for these calls, so pass every argument.

### Add the SDK

**CocoaPods (recommended):**

```ruby
pod 'PentabitAds', :git => 'https://github.com/Pentabit-Labs-LLC/pentabitads.git', :tag => 'LATEST_VERSION'
```

This brings in all three frameworks below. **Manual:** download `PentabitAds-iOS.zip` from `https://pentabit-labs-llc.github.io/pentabitads/ios/LATEST_VERSION/PentabitAds-iOS.zip` and add all three frameworks to your Xcode project: `PentabitAds.xcframework`, `PentabitAdsVideo.xcframework` and `PentabitAnalytics.xcframework`. The video framework is required (most interstitial and rewarded ads are video) and so is Analytics (action reporting, started by `PentabitAds.shared.initialize`; you do not initialize it yourself). They are static frameworks, so set *Embed* to **Do Not Embed**. Minimum deployment target: iOS 14.

### Initialize once

```swift
import PentabitAds
import PentabitAdsVideo

@main
struct MyApp: App {
    init() {
        PentabitAdsVideo.shared.install()   // required, call before initialize
        PentabitAds.shared.initialize(
            context: PlatformContext(),
            options: PentabitAdsOptions(
                appKey: "YOUR_APP_KEY",
                audience: .general,       // use .childDirected for apps for children
                debug: isDebugBuild       // true shows Pentabit test ads
            )
        )
    }
    var body: some Scene { WindowGroup { ContentView() } }
}
```

Define `isDebugBuild` yourself, for example with `#if DEBUG`.

### Report in-app actions (required)

Action reporting comes with the Ads SDK. `PentabitAds.initialize` starts it with the same app key, audience, debug setting and consent, so you make no extra initialize call (the `pentabit-analytics` dependency is listed in "Add the SDK" above). Installs and retention (days 1, 3, 7, 14 and 30) are reported automatically. Report the actions only your app knows; advertisers are billed on these actions, now and when the network runs paid campaigns:

```swift
PentabitAnalytics.shared.trackRegistration(method: nil)
PentabitAnalytics.shared.trackLevelReached(level: 10)
PentabitAnalytics.shared.trackPurchase(revenue: 4.99, currency: "USD", productId: "gems_100")
PentabitAnalytics.shared.trackSubscribe(revenue: 9.99, currency: "USD", productId: "pro_monthly")
```

On iOS, use `PentabitAnalytics.shared` after `import PentabitAnalytics`.

Full list and options: see "Pentabit Analytics" below.

### Revenue callbacks (all formats)

Every format reports `onAdImpression()` (once per ad) and, right after it, `onAdPaid(value:)` with `value.valueMicros` (millionths of `value.currencyCode`, 1_000_000 = 1 USD). The backend sends the amount with the ad; it is `0` USD while only cross-promotion is served. Banner uses `BannerListener`, interstitial / rewarded / app open use `AdShowListener`, native and icon use `NativeAdEventListener`.

### Interstitial

#### Load

```swift
final class LoadListener: AdLoadListener {
    var ready: () -> Void = {}
    override func onLoaded() { ready() }                              // ready to show
    override func onLoadFailed(error: AdError) { }
}

// Keep these as properties so they stay alive
let interstitial = PentabitAds.shared.interstitial(placementId: "aks-xxxxxxxxxxx-xxx")
let loadListener = LoadListener()
interstitial.load(listener: loadListener)
```

#### Show

```swift
final class InterstitialShowListener: AdShowListener {
    var finished: () -> Void = {}
    override func onShown() { }
    override func onClicked() { }
    override func onClosed() { finished() }
    override func onShowFailed(error: AdError) { finished() }
}

// Later, from a view controller that is on screen:
let show = InterstitialShowListener()
show.finished = { goToNextScreen() }
if interstitial.isReady {
    interstitial.show(host: self, listener: show)
} else {
    goToNextScreen()
}
```

#### Revenue reporting

Add the two callbacks to the show listener:

```swift
override func onAdImpression() { }
override func onAdPaid(value: AdValue) {
    logRevenue(Double(value.valueMicros) / 1_000_000.0, value.currencyCode)
}
```

### Rewarded

#### Load

```swift
let rewarded = PentabitAds.shared.rewarded(placementId: "aks-xxxxxxxxxxx-xxx")
rewarded.load(listener: loadListener)     // same LoadListener as above
```

#### Show

```swift
final class RewardedShowListener: AdShowListener {
    var reward: (Int) -> Void = { _ in }
    var finished: () -> Void = {}
    override func onRewardEarned(reward item: RewardItem) { reward(Int(item.amount)) }   // grant the reward here, and only here
    override func onClosed() { finished() }
    override func onShowFailed(error: AdError) { finished() }
}

let show = RewardedShowListener()
show.reward = { amount in giveLives(amount) }
if rewarded.isReady {
    rewarded.show(host: self, listener: show)
}
```

`onRewardEarned` can arrive slightly after `onClosed`.

#### Revenue reporting

```swift
override func onAdImpression() { }
override func onAdPaid(value: AdValue) {
    logRevenue(Double(value.valueMicros) / 1_000_000.0, value.currencyCode)
}
```

### App open

#### Load

```swift
let appOpen = PentabitAds.shared.appOpen(placementId: "aks-xxxxxxxxxxx-xxx")
appOpen.load(listener: loadListener)
```

#### Show

```swift
// when the app returns to the foreground (for example on UIApplication.willEnterForegroundNotification):
if appOpen.isReady {
    appOpen.show(host: topViewController, listener: InterstitialShowListener())
}
```

#### Revenue reporting

Same two callbacks as the interstitial: `onAdImpression()` and `onAdPaid(value:)` on the show listener.

### Banner

**Banner sizes.** Set the size before `load`. The server returns a banner of exactly that size, or no ad (`NO_FILL`); it never stretches a banner of another size.

| Size | `adSize` | Dp |
|---|---|---|
| Banner | `BannerSize.BANNER` (default) | 320x50 |
| Large banner | `BannerSize.LARGE_BANNER` | 320x100 |
| Medium rectangle | `BannerSize.MEDIUM_RECTANGLE` | 300x250 |

```swift
banner.adSize = .largeBanner   // before load
```


#### Load and show (UIKit)

```swift
final class BannerEvents: BannerListener {
    override func onLoaded() { }
    override func onLoadFailed(error: AdError) { }
    override func onShown() { }
    override func onClicked() { }
}

let banner = PentabitBannerView(frame: CGRect(x: 0, y: 0, width: 320, height: 50))
view.addSubview(banner)
banner.load(placementId: "aks-xxxxxxxxxxx-xxx", listener: BannerEvents())
// when you are done with it:
banner.destroy()
```

#### Load and show (SwiftUI)

```swift
struct PentabitBanner: UIViewRepresentable {
    let adUnitId: String
    func makeUIView(context: Context) -> PentabitBannerView {
        let banner = PentabitBannerView(frame: CGRect(x: 0, y: 0, width: 320, height: 50))
        banner.load(placementId: adUnitId, listener: BannerEvents())
        return banner
    }
    func updateUIView(_ uiView: PentabitBannerView, context: Context) { }
    static func dismantleUIView(_ uiView: PentabitBannerView, coordinator: ()) { uiView.destroy() }
}

// usage
PentabitBanner(adUnitId: "aks-xxxxxxxxxxx-xxx").frame(width: 320, height: 50)
```

#### Revenue reporting

Add the two callbacks to `BannerEvents`:

```swift
override func onAdImpression() { }
override func onAdPaid(value: AdValue) {
    logRevenue(Double(value.valueMicros) / 1_000_000.0, value.currencyCode)
}
```

### Native

On iOS you draw the ad with your own views and report what happens. You must show the "Ad" label and an (i) button that calls `openPrivacyPolicy()`.

#### Load

```swift
final class NativeListener: NativeAdListener {
    var loaded: (NativeAd) -> Void = { _ in }
    override func onLoaded(ad: NativeAd) { loaded(ad) }
    override func onLoadFailed(error: AdError) { }
}

let nativeListener = NativeListener()
nativeListener.loaded = { ad in self.showNative(ad) }
PentabitAds.shared.nativeAds(placementId: "aks-xxxxxxxxxxx-xxx").load(listener: nativeListener)
```

#### Show

```swift
func showNative(_ ad: NativeAd) {
    titleLabel.text = ad.title
    bodyLabel.text = ad.body
    ctaButton.setTitle(ad.callToAction, for: .normal)
    adTagLabel.text = ad.sponsoredLabel                   // always show this label
    if let path = ad.iconPath { iconView.image = UIImage(contentsOfFile: path) }
    if let path = ad.imagePath { imageView.image = UIImage(contentsOfFile: path) }
    ad.recordImpression()                                 // when it is first on screen
    // ctaButton tap:   _ = ad.recordClick()
    // (i) button tap:  _ = ad.openPrivacyPolicy()
}
// When you remove the ad: ad.destroy()
```

In SwiftUI, put the same assets in a `View` (`Image(uiImage: UIImage(contentsOfFile: path)!)`), call `ad.recordImpression()` in `.onAppear` and `ad.recordClick()` in the button action.

#### Revenue reporting

Set the listener before `recordImpression()`:

```swift
final class NativeEvents: NativeAdEventListener {
    override func onAdImpression() { }
    override func onAdPaid(value: AdValue) {
        logRevenue(Double(value.valueMicros) / 1_000_000.0, value.currencyCode)
    }
    override func onClicked() { }
}
ad.setEventListener(listener: NativeEvents())
```

### Icon

#### Load

```swift
PentabitAds.shared.iconAds(placementId: "aks-xxxxxxxxxxx-xxx").load(listener: nativeListener)   // same NativeListener as native
```

#### Show

Draw `ad.iconPath` in a 64 to 128 pt tile with the "Ad" label and the (i) button, then call `recordImpression()` when it is on screen and `recordClick()` on tap:

```swift
func showIcon(_ ad: NativeAd) {
    if let path = ad.iconPath { iconButton.setImage(UIImage(contentsOfFile: path), for: .normal) }
    adTagLabel.text = ad.sponsoredLabel
    ad.recordImpression()
    // iconButton tap:  _ = ad.recordClick()
    // (i) button tap:  _ = ad.openPrivacyPolicy()
}
```

#### Revenue reporting

Same as native: `ad.setEventListener(listener: NativeEvents())` before `recordImpression()`.

### App Store setup

- To use the advertising ID for personalized ads, add `NSUserTrackingUsageDescription` to Info.plist and ask for permission with `ATTrackingManager.requestTrackingAuthorization` **before** the first ad request. If you do not ask, ads still work and are not personalized.
- Add the Pentabit SKAdNetwork IDs (from the Pentabit team) to `SKAdNetworkItems` in Info.plist.


---

## Consent and apps for children

Tell the SDK who your audience is when you initialize:

| `audience` | Use it when |
|---|---|
| `GENERAL` | General audience app |
| `MIXED_AUDIENCE` | Used by adults and children |
| `CHILD_DIRECTED` | App is for children (Google Families policy, COPPA, Apple Kids Category) |

For `CHILD_DIRECTED` apps the SDK uses no advertising ID and no personalization. On Android, do **not** add the `AD_ID` permission, and on iOS do not ask for tracking permission.

If you collect consent (GDPR, US privacy laws), pass the result to the SDK at start and whenever it changes:

```kotlin
PentabitAds.setConsent(
    ConsentSignals(
        personalizedAdsAllowed = TriState.TRUE,   // TRUE, FALSE or UNKNOWN
        gdprApplies = TriState.TRUE,
        tcfString = tcfStringFromYourConsentTool,
        usPrivacyOptOut = false,                  // true if the user opted out of sale/sharing
        isUnderAgeOfConsent = TriState.FALSE,
    )
)
```

Imports: `com.pentabitlabs.pentabitads.core.privacy.ConsentSignals` and `TriState`. If GDPR applies and no consent string is supplied, ads do not load (`CONSENT_BLOCKED`). Without consent the SDK shows non-personalized ads.

---

## Errors

A load or show failure gives you an `AdError` with a `code` and a `message`. The SDK never throws, so always continue your app's flow in `onLoadFailed` and `onShowFailed`.

| Code | Meaning | What to do |
|---|---|---|
| `NOT_INITIALIZED` | `initialize` was not called | Initialize at app start |
| `PLACEMENT_NOT_FOUND` | Wrong ad unit ID, or the ID is for a different format | Check the ID and format |
| `PLACEMENT_DISABLED` / `KILL_SWITCH` | Ads are paused for this placement or app | Try later |
| `APP_NOT_AUTHORIZED` | The app key was not issued for this app (package name on Android, bundle ID on iOS). Ads stop until it matches | Use the key Pentabit gave you for this exact package or bundle ID |
| `NO_FILL` | No ad available for this placement right now | Try again later |
| `CONSENT_BLOCKED` | Consent is required first | Call `setConsent` |
| `NO_FILL` | No ad available right now | Normal. Try again later |
| `TIMEOUT` / `NETWORK` | Slow or no connection | Try again when online |
| `ASSET_FAILED` | The ad files could not be loaded | Try again later |
| `EXPIRED` | The ad waited too long before being shown | Load a new ad |
| `INTERNAL` | Unexpected problem. A video ad also gives this if `pentabit-ads-video` was not added or `PentabitAdsVideo.install()` was not called. | See the message |

## Testing

- With `debug = true` (Android `BuildConfig.DEBUG`) the SDK shows **Pentabit test ads** for every format and writes logs (Logcat tag prefix `Pentabit`, Xcode console `[Pentabit...]`). No live ads are shown, no revenue is earned.
- Release builds must use `debug = false` to show live ads. If a release build shows test ads, `debug` is wrongly `true`.
- Use the same app key and ad unit IDs in debug and release.
- Never click your own live ads. Test with a debug build.

## Best practices

- **Load early, show later.** Call `load()` before you need the ad (screen start, or right after the last ad closed) and check `isReady` before `show`.
- **Keep one ad object per placement** in a field. An ad that waits too long expires, so load a new one.
- **Never block your app on an ad.** If an ad is not ready or fails, continue the user's flow.
- **Respect the user.** No full-screen ad straight after another, none when the app is opened from a notification, none in the middle of a task. Do not cover or hide ads, and keep banners away from buttons.
- **Call the SDK from the main thread.** Callbacks come back on the main thread.
- **Always show the "Ad" label** on native and icon ads (`sponsoredLabel`).
- Test a **release build** before publishing to confirm nothing was stripped (ProGuard rules are included).

---

## Pentabit Analytics (action reporting)

The Analytics part of the SDK reports the actions advertisers pay for: installs, retention (days 1, 3, 7, 14, 30) and what users do after the install (registration, purchases and so on). It has nothing to show and no `load` or `show`.

This is **required in every app that uses the network**. Add the `pentabit-analytics` dependency (listed under "Add the SDK"); `PentabitAds.initialize` starts it, so you do not initialize it yourself. Advertisers are billed on these actions, now and when the network runs paid campaigns.

In an advertised app that does not show ads, add only this module and initialize it with `PentabitAnalytics.initialize` as shown below.

### Android

```kotlin
// app/build.gradle.kts
implementation("com.pentabitlabs.pentabitads:pentabit-analytics:LATEST_VERSION")
```

```kotlin
import com.pentabitlabs.pentabitads.analytics.PentabitAnalytics
import com.pentabitlabs.pentabitads.analytics.AnalyticsOptions
import com.pentabitlabs.pentabitads.analytics.initialize

class MyApp : Application() {
    override fun onCreate() {
        super.onCreate()
        PentabitAnalytics.initialize(this, AnalyticsOptions(appKey = "YOUR_APP_KEY", audience = AudienceProfile.GENERAL, debug = BuildConfig.DEBUG))
    }
}
```

The SDK reports installs and day 1, 3, 7, 14 and 30 retention by itself. You report the actions only your app knows, wherever they happen in your app:

```kotlin
PentabitAnalytics.trackRegistration()
PentabitAnalytics.trackTutorialComplete()
PentabitAnalytics.trackLevelReached(10)
PentabitAnalytics.trackFeatureUsed("export_pdf")
PentabitAnalytics.trackPurchase(revenue = 4.99, currency = "USD", productId = "gems_100")
PentabitAnalytics.trackSubscribe(revenue = 9.99, currency = "USD", productId = "pro_monthly")
PentabitAnalytics.track("watched_intro")             // your own event name: lower case letters, digits, underscores
```

Call `trackPurchase` and `trackSubscribe` once per transaction, after the store confirms it. If your app opens from an ad link, pass the link to Analytics:

```kotlin
override fun onNewIntent(intent: Intent) {
    super.onNewIntent(intent)
    intent.data?.let { PentabitAnalytics.handleDeepLink(it.toString()) }
}
```

### iOS

```swift
import PentabitAnalytics

PentabitAnalytics.shared.initialize(
    context: PlatformContext(),
    options: AnalyticsOptions(appKey: "YOUR_APP_KEY", audience: .general, debug: isDebugBuild)
)
PentabitAnalytics.shared.trackRegistration(method: nil)
PentabitAnalytics.shared.trackPurchase(revenue: 4.99, currency: "USD", productId: "gems_100")
```

Add the Pentabit SKAdNetwork IDs to `SKAdNetworkItems` in Info.plist. Consent and child-directed settings work the same as for the Ads SDK (`PentabitAnalytics.setConsent`). In a child-directed app, Analytics sends nothing.
