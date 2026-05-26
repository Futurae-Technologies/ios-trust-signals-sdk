# Changelog

All notable changes to TrustSignals will be documented in this file.

Format follows [Keep a Changelog](https://keepachangelog.com/en/1.1.0/).
Versions follow [Semantic Versioning](https://semver.org/spec/v2.0.0.html).

## [0.0.1-alpha] - 2026-05-26

### Added
- Initial alpha release of TrustSignals SDK for iOS.
- Signal collection: device, OS, locale, network, location, Bluetooth, WiFi, nearby devices, battery, security.
- `TrustSignalsSDK.initialize(_:)` for SDK setup.
- `TrustSignalsSDK.collect()` for on-demand local collection.
- `TrustSignalsSDK.collectAndUpload(accessToken:accountID:)` for collect + upload.
- `TrustSignalsSDK.scheduleCollections(interval:accessToken:accountID:)` for recurring collection.
- `TrustSignalsSDK.registerErrorHandler(_:)` for error callbacks on scheduled collections.
- `TrustSignalsSDK.collections` AsyncStream for real-time observation.
- Fire-and-forget upload to Collection API (`POST /api/v1/observations`).
- 14 parallel collectors with hard 20-second timeout.
- Permission-aware design: denied collectors report `permission: false` without breaking schema.
- `TSPermissionPolicy` for overriding permission checks in tests/demos.
- DocC documentation catalog.
- Distributed as pre-built XCFramework via Swift Package Manager.

<!-- ## [Unreleased] -->
