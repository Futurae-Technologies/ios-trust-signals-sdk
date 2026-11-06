# Changelog

All notable changes to TrustSignals will be documented in this file.

Format follows [Keep a Changelog](https://keepachangelog.com/en/1.1.0/).
Versions follow [Semantic Versioning](https://semver.org/spec/v2.0.0.html).

## [1.0.0] - 2026-11-06

### Added
- `TSObservation.networkState` is now collected and sent as `observation.networkState`. `networkType` is one of
  `NONE` / `WIFI` / `CELLULAR` / `ETHERNET` / `OTHER`. `vpnActive` is best effort:
  iOS has no public API for another app's VPN, so it is inferred from tunnel interfaces on the current network path.
  `proxyHost` is the system HTTP proxy host, omitted when none is set. Needs no permission.
- `TSError.invalidConfiguration(field:reason:)`, thrown when `initialize(_:)` refuses a configuration.

### Changed
- **BREAKING:** `initialize(_:)` is now `async throws` and validates `TSConfiguration`: `collectionUrl` must be an
  `https` URL with a host (plain `http` was accepted before), and `sensorTag` must not be blank. An invalid
  configuration is not applied: a stopped SDK stays stopped, a running SDK keeps its configuration. Call sites need `try`.
- **BREAKING:** `accountId` must be 1–50 ASCII letters, digits or `-`; otherwise `invalidIdentifier(field: "accountId", reason:)`.
  Previously only a blank value was rejected.

### Fixed
- `registerErrorHandler(_:)` is no longer called for on-demand `collectAndUpload` failures, which the caller already
  receives (thrown error or `TSUploadOutcome.failures`). It now reports only uploads that fail in a scheduled or background cycle.

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
- `TSLocation.accuracy` and `speed`.
- `TSNetworkState` and `TSObservation.networkState`.
- `TSError.noAccountsProvided`, `blankAccountId`, `missingAccessToken` and `invalidIdentifier(field:reason:)` for invalid input, thrown before collection starts.
- On-demand uploads complete when the app moves to the background.

### Changed
- **BREAKING:** `collectAndUpload` and `scheduleCollections` take `TSCredentials` instead of `accessToken:accountID:`.
- **BREAKING:** `TSConfiguration.serverURL` → `collectionUrl`, now the full endpoint URL (e.g. `…/api/v1/collections`); the SDK no longer appends `/api/v1/observations`. `tag` → `sensorTag`.
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

