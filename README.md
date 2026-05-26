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
    .package(url: "https://github.com/Futurae-Technologies/ios-trust-signals-sdk.git", exact: "0.1.0-alpha")
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

Register a handler for errors during scheduled collections:

```swift
await TrustSignalsSDK.registerErrorHandler { accountID, error in
    print("Collection failed for \(accountID): \(error)")
}
```

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

## Documentation

Browse the full API reference at **[futurae-technologies.github.io/ios-trust-signals-sdk](https://futurae-technologies.github.io/ios-trust-signals-sdk/)**.

## License

Copyright (c) Futurae Technologies AG. All rights reserved.
