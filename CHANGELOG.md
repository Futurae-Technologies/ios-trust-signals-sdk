# Changelog

All notable changes to TrustSignals will be documented in this file.

Format follows [Keep a Changelog](https://keepachangelog.com/en/1.1.0/).
Versions follow [Semantic Versioning](https://semver.org/spec/v2.0.0.html).

## [0.1.0-alpha] - 2026-10-05

### Added
- `TSCredentials` for per-account identity (`accountId`, `accessToken`, `serviceId`, `unitId`, `interactionId`, `verificationStatus`).
- `TSVerificationStatus` for the account's verification state (`.verified`, `.unverified`, `.fraud`).
- `TrustSignalsSDK.collectAndUpload(_:timeout:)` for collect + upload for one or many accounts in a single sweep.
- `TSUploadOutcome` for per-account results of a multi-account upload.
- `TSUploadError` for per-account failures when no account was uploaded.
- `TrustSignalsSDK.scheduleCollections(collectionInterval:credentials:)` for recurring collection per account.
- `TrustSignalsSDK.scheduleCollections(_:)` and `TSScheduledRequest` for scheduling many accounts, each on its own interval.
- `TrustSignalsSDK.stopScheduledCollections(accountId:)` and `stopScheduledCollections()` for stopping schedules without tearing down the SDK.
- `TrustSignalsSDK.schedules` for reading active schedules.
- `TrustSignalsSDK.registerBackgroundTasks(identifier:)` for running schedules in the background.
- `timeout:` parameter on `collect` and `collectAndUpload` for a per-call collection budget.
- `TSConfiguration.collectionReuseWindow` for reusing recent signals across scheduled accounts.
- `TSError.noAccountsProvided`, `blankAccountId`, `missingAccessToken` and `invalidIdentifier(field:reason:)` for invalid input, thrown before collection starts.
- On-demand uploads complete when the app moves to the background.

### Changed
- **BREAKING:** `collectAndUpload` and `scheduleCollections` take `TSCredentials` instead of `accessToken:accountID:`.
- **BREAKING:** `TSConfiguration.serverURL` → `collectionUrl` (full endpoint URL), `tag` → `sensorTag`.
- **BREAKING:** `TrustSignalsSDK.stop()` → `stopAll()`.
- **BREAKING:** `TSCollection.timestamp` / `TSDevice.timestamp` → `observationTime: Date`, `TSCollection.tag` → `sensorTag`, `TSLocationCollection` → `TSLocation`, `TSObservation.locationCollection` → `location`, `permission` → `permissionGranted`.
- **BREAKING:** `TSAuthenticationError` → `TSError.authenticationFailed(statusCode:body:)`.
- **BREAKING:** `TSError.notStarted` → `notInitialized`, `submissionRejected` → `uploadRejected`, `submissionTransportFailed` → `uploadTransportFailed`, `collectionTimedOut` → `collectionTimedOut(after:)`.
- Scheduled collections report failures per account through `registerErrorHandler(_:)`; one failing account does not stop the others.

### Removed
- `TSInfo` and `TrustSignalsSDK.info` — use `TrustSignalsSDK.version`.
- `TSConfiguration.appID` — replaced by `TSCredentials`.
- `TSConfiguration.backgroundTaskIdentifier` — use `registerBackgroundTasks(identifier:)`.
- `TSError.blankAppID` — replaced by `invalidIdentifier(field:reason:)`.

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

