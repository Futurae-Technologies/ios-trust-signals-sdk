# TrustSignals for iOS

**TrustSignals** is Futurae's Trust Signals SDK for iOS. It collects device, network, location, Bluetooth, and environmental signals and uploads them to the Futurae Trust Signals platform for risk assessment and fraud detection.

## Requirements

| | Minimum |
|---|---|
| **iOS** | 16.0+ |
| **Swift** | 5.9+ |
| **Xcode** | 16+ |

## Installation

### Swift Package Manager

Add TrustSignals to your project via Xcode or `Package.swift`:

**Xcode:** File → Add Package Dependencies → enter:

```
https://github.com/Futurae-Technologies/ios-trust-signals-sdk.git
```

**Package.swift:**

```swift
dependencies: [
    // Pre-release versions require exact pinning:
    .package(url: "https://github.com/Futurae-Technologies/ios-trust-signals-sdk.git", exact: "0.0.1-alpha")
    // Stable releases can use range-based versioning:
    // .package(url: "https://github.com/Futurae-Technologies/ios-trust-signals-sdk.git", from: "1.0.0")
]
```

Then add `TrustSignals` to your target's dependencies.

## Quick Start

### 1. Initialize

Call `initialize` once on app launch:

```swift
import TrustSignals

await TrustSignalsSDK.initialize(
    TSConfiguration(
        serverURL: URL(string: "https://trustsignals.example.com")!,
        appID: "your-app-id"
    )
)
```

### 2. Collect & Upload

Collect device signals and upload them with an OAuth2 access token:

```swift
let collection = try await TrustSignalsSDK.collectAndUpload(
    accessToken: "your-oauth2-token",
    accountID: "user-account-id"
)
```

### 3. Schedule Recurring Collections

Automatically collect and upload on a fixed interval (default: 30 minutes):

```swift
await TrustSignalsSDK.scheduleCollections(
    interval: .seconds(60),
    accessToken: "your-oauth2-token",
    accountID: "user-account-id"
)
```

### 4. Collect Only (No Upload)

```swift
let collection = try await TrustSignalsSDK.collect()
```

### 5. Observe Collections

Subscribe to a real-time stream of all collections:

```swift
for await collection in await TrustSignalsSDK.collections {
    print("Collection: \(collection.collectionId)")
}
```

### 6. Error Handling

`collect()` and `collectAndUpload(...)` throw their errors directly to the
caller — wrap them in `try`/`catch`. Errors from **scheduled** collections run
in the background, so they are instead delivered to a registered handler:

```swift
await TrustSignalsSDK.registerErrorHandler { accountID, error in
    switch error {
    case is TSAuthenticationError:
        // Access token expired/rejected (HTTP 401/403).
        // Obtain a fresh token from your backend, then re-schedule:
        //
        // await TrustSignalsSDK.scheduleCollections(
        //     interval: .seconds(1800),
        //     accessToken: newToken,
        //     accountID: accountID
        // )
        break
    default:
        // Log or report other errors (transport, non-2xx, timeout).
        print("Collection failed for \(accountID): \(error)")
    }
}
```

> **Note:** The handler may be invoked off the main thread. Hop to
> `@MainActor` before touching UI.

#### Error behaviour summary

| Error type | Retry | Where it surfaces |
|---|---|---|
| Transport failure — DNS/TLS/timeout (`TSError.submissionTransportFailed`) | No | Thrown from `collectAndUpload(...)`; delivered to handler when scheduled |
| HTTP 401 / 403 (`TSAuthenticationError`) | No | Thrown from `collectAndUpload(...)`; delivered to handler when scheduled |
| Other non-2xx HTTP (`TSError.submissionRejected`) | No | Thrown from `collectAndUpload(...)`; delivered to handler when scheduled |
| Collection timed out with no data (`TSError.collectionTimedOut`) | No | Thrown from `collect()` / `collectAndUpload(...)` |
| Individual collector failed | No | Not surfaced — that one signal is omitted and the collection still completes (with `timedOut` flagged on partial timeouts) |
| SDK used before `initialize(_:)` (`TSError.notStarted`) | No | Thrown from the called method |

The SDK performs **no automatic retries** and keeps **no offline queue** — each
submission is a single attempt. A failed scheduled cycle is reported to the
handler and the schedule simply continues at the next interval.

### 7. Stop

```swift
await TrustSignalsSDK.stop()
```

## Permissions

The SDK collects signals from multiple sources. Some require permissions declared in your app's `Info.plist`:

| Signal | Permission | Info.plist Key |
|--------|-----------|----------------|
| GPS Location | Location | `NSLocationWhenInUseUsageDescription` |
| Bluetooth | Bluetooth | `NSBluetoothAlwaysUsageDescription` |
| WiFi Network | Location + Entitlement | `NSLocationWhenInUseUsageDescription` + Access WiFi Information capability |
| Nearby Devices | Local Network | `NSLocalNetworkUsageDescription` + `NSBonjourServices` |

Collectors that lack permission gracefully report `permission: false` without affecting other signals.

### Bonjour services

The **Nearby Devices** collector browses for Bonjour service types declared in
your app's `Info.plist` under `NSBonjourServices`. iOS only allows browsing for
service types that are explicitly listed — any type not present is silently
skipped. To match the SDK's full coverage, add the following list:

```xml
<key>NSBonjourServices</key>
<array>
    <string>_smb._tcp.</string>
    <string>_privet._tcp.</string>
    <string>_device-info._tcp.</string>
    <string>_sftp-ssh._tcp.</string>
    <string>_airplay._tcp.</string>
    <string>_scanner._tcp.</string>
    <string>_mediaremotetv._tcp.</string>
    <string>_rdlink._tcp.</string>
    <string>_rfb._tcp.</string>
    <string>_uscan._tcp.</string>
    <string>_companion-link._tcp.</string>
    <string>_apple-mobdev2._tcp.</string>
    <string>_b._dns-sd._udp.</string>
    <string>_afpovertcp._tcp.</string>
    <string>_nfs._tcp.</string>
    <string>_webdav._tcp.</string>
    <string>_ftp._tcp.</string>
    <string>_ssh._tcp.</string>
    <string>_eppc._tcp.</string>
    <string>_http._tcp.</string>
    <string>_telnet._tcp.</string>
    <string>_printer._tcp.</string>
    <string>_ipp._tcp.</string>
    <string>_pdl-datastream._tcp.</string>
    <string>_riousbprint._tcp.</string>
    <string>_daap._tcp.</string>
    <string>_dpap._tcp.</string>
    <string>_ichat._tcp.</string>
    <string>_presence._tcp.</string>
    <string>_ica-networking._tcp.</string>
    <string>_airport._tcp.</string>
    <string>_xserveraid._tcp.</string>
    <string>_distcc._tcp.</string>
    <string>_apple-sasl._tcp.</string>
    <string>_workstation._tcp.</string>
    <string>_servermgr._tcp.</string>
    <string>_raop._tcp.</string>
    <string>_xcs2p._tcp.</string>
</array>
```

By default the SDK browses every type listed here (read from `NSBonjourServices`
at init). To narrow the set, pass an explicit `bonjourServices:` array to
`TSConfiguration`.

## Collected Signals

| Category | Examples |
|----------|---------|
| **Device** | Model, screen resolution, thermal state, proximity |
| **OS** | Version, uptime, low power mode |
| **Network** | WiFi SSID, local IP, BLE peripherals, nearby devices |
| **Location** | Latitude, longitude |
| **App** | Version, build number |
| **Battery** | Level, charging state |
| **Security** | Debugger detection |
| **Identifiers** | Vendor ID (IDFV) |

## Example App

A minimal SwiftUI test app is included in the `test-app/` directory. Open `test-app/TrustSignalsTestApp.xcodeproj` in Xcode, select a simulator or device, and run.

The app lets you configure the SDK (App ID, tag), then exercise the main SDK flows from a single screen:

- **Collect Now** — on-demand collection with no upload
- **Collect & Upload** — one-shot collection and submission using an Account ID and OAuth2 access token
- **Schedule** — recurring collect-and-upload at a configurable interval

## Documentation

Browse the full API reference at **[futurae-technologies.github.io/ios-trust-signals-sdk](https://futurae-technologies.github.io/ios-trust-signals-sdk/)**.

## License

Copyright (c) Futurae Technologies AG. All rights reserved.
