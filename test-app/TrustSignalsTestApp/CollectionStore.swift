import Foundation
import TrustSignals
import SwiftUI
import Security

@MainActor
final class CollectionStore: ObservableObject {
    
    struct UploadOutcome: Sendable {
        let isSuccess: Bool
        let detail: String
    }
    
    @Published private(set) var collections: [TSCollection] = []
    @Published private(set) var isBusy: Bool = false
    @Published var lastError: String?
    @Published private(set) var intervals: [String: Int] = [:]
    static let defaultIntervalSeconds = 0
    @Published var accessToken: String = ""
    @Published var accountIds: String = ""

    // MARK: - Identity
    //
    // Every field is required and the host owns every value: the SDK generates none,
    // not even the per-installation identifier. serviceId and unitId come from the
    // launch screen; an account with a client override uses its own serviceId and
    // token instead. All of them travel in each account's TSCredentials.

    /// From the launch screen; `unitId` never changes after launch.
    let settings: LaunchSettings
    var unitId: String { settings.unitId }

    init(settings: LaunchSettings) {
        self.settings = settings
        self.overrides = ClientOverrideStore.loadAll()
    }

    // MARK: - OAuth2 client override, per account
    //
    // Client ID, client secret and service ID go together — the client credentials are
    // issued for one specific service ID, so a partial override would be rejected with a
    // 403. An override is simply different TSCredentials for that account: its own token
    // (fetched with the client-credentials grant) and service ID, on every upload —
    // on demand and scheduled. Accounts without one use the pasted token and the launch
    // Service ID.

    @Published private(set) var overrides: [String: ClientOverride]
    @Published private(set) var overrideTokens: [String: String] = [:]
    @Published private(set) var tokenStatuses: [String: String] = [:]

    func hasOverride(_ accountId: String) -> Bool { overrides[accountId] != nil }

    /// The `serviceId` this account's uploads carry.
    func serviceId(for accountId: String) -> String {
        overrides[accountId]?.serviceId ?? settings.serviceId
    }

    func tokenStatus(for accountId: String) -> String? { tokenStatuses[accountId] }

    /// The `serviceId`s the entered accounts send, for the wire preview.
    var previewServiceId: String {
        let ids = Set(parsedAccountIds.map(serviceId(for:)))
        return ids.isEmpty ? settings.serviceId : ids.sorted().joined(separator: ", ")
    }

    /// The values the editor starts from: the saved override, or the build's defaults.
    func draftOverride(for accountId: String) -> ClientOverride {
        overrides[accountId] ?? ClientOverride(
            clientId: TestAppConfig.defaultClientId,
            clientSecret: TestAppConfig.defaultClientSecret,
            serviceId: settings.serviceId,
            authBaseURL: settings.authBaseURL
        )
    }

    /// Stands in for the host's enrolment state, which a sample app does not have:
    /// `unverified` on a fresh install or after logout, `verified` once the device is
    /// bound to an account, `fraud` TBD.
    @Published var verificationStatus: TSVerificationStatus = .unverified

    /// The per-installation identifier, minted here and kept across launches. Editable
    /// so a tester can point observations at a different installation, or feed the SDK
    /// a malformed value on purpose; every change is persisted.
    @Published var interactionId: String = InstallationIdentifier.loadOrCreate() {
        didSet { InstallationIdentifier.save(interactionId) }
    }

    @Published private(set) var schedules: [String: Duration] = [:]
    @Published private(set) var tokenRecoveries: Int = 0
    @Published private(set) var uploads: [UUID: [String: UploadOutcome]] = [:]
    @Published private(set) var collectOnly: Set<UUID> = []

    private var observerTask: Task<Void, Never>?
    private var isRecoveringPastedToken = false
    private var lastRejectedToken: String?
    private var recoveringAccounts: Set<String> = []
    /// Per account, the token the last recovery fetched. If that one is rejected too,
    /// fetching another will not help.
    private var tokenFetchedInRecovery: [String: String] = [:]

    func startObserving() async {
        // Overrides saved in an earlier session apply from the start.
        for (accountId, override) in overrides {
            await fetchToken(for: accountId, override: override)
        }

        observerTask?.cancel()
        observerTask = Task { [weak self] in
            let stream = await TrustSignalsSDK.collections
            for await collection in stream {
                await MainActor.run { self?.append(collection) }
            }
        }

        await TrustSignalsSDK.registerErrorHandler { [weak self] accountId, error in
            Task { @MainActor in
                guard let self else { return }
                self.record(accountId: accountId, outcome: .init(
                    isSuccess: false,
                    detail: Self.reason(for: error)
                ))
                if case TSError.authenticationFailed(let statusCode, _) = error {
                    self.lastError = "\(accountId): token rejected — refreshing and re-arming"
                    await self.recoverFromRejectedToken(accountId: accountId, statusCode: statusCode)
                } else {
                    self.lastError = "\(accountId): \(Self.reason(for: error))"
                }
            }
        }
    }

    /// Files an outcome against the newest collection on screen. Scheduled failures
    /// arrive without one, so this is a best guess for display — the SDK reports the
    /// account and the reason, not which sweep they belong to.
    private func record(accountId: String, outcome: UploadOutcome) {
        guard let row = collections.first?.collectionId else { return }
        uploads[row, default: [:]][accountId] = outcome
    }

    static func reason(for error: Error) -> String {
        switch error {
        case TSError.authenticationFailed(let statusCode, _):
            return "HTTP \(statusCode) — token rejected (expired, wrong scope, or serviceId/token mismatch)"
        case TSError.uploadRejected(let statusCode, let body):
            return "HTTP \(statusCode) rejected by BE\(body.map { " — \($0.prefix(120))" } ?? "")"
        case TSError.uploadTransportFailed(let underlying):
            return "network failure — \(underlying)"
        case TSError.collectionTimedOut(let after):
            return "collection timed out (\(after)) with no signals"
        case TSError.notInitialized:
            return "SDK not initialized"
        default:
            return error.localizedDescription
        }
    }

    private static func short(_ id: UUID) -> String {
        "\(id.uuidString.prefix(8))…"
    }


    private func recoverFromRejectedToken(accountId: String, statusCode: Int) async {
        guard armedAccounts[accountId] != nil else { return }

        if let override = overrides[accountId] {
            guard !recoveringAccounts.contains(accountId) else { return }
            recoveringAccounts.insert(accountId)
            defer { recoveringAccounts.remove(accountId) }

            // A 403 means the token is valid but not authorized for this service ID;
            // a fresh one would carry the same claims.
            guard statusCode == 401 else {
                lastError = "\(accountId): HTTP \(statusCode) — the client is not authorized for service ID "
                    + "\(override.serviceId). Check the account's client override."
                return
            }
            guard overrideTokens[accountId] != tokenFetchedInRecovery[accountId] else {
                lastError = "\(accountId): a freshly fetched token was rejected too — check the client override."
                return
            }
            guard await fetchToken(for: accountId, override: override) else { return }
            tokenFetchedInRecovery[accountId] = overrideTokens[accountId]
        } else {
            // Every account without an override shares the pasted token: one recovery
            // covers them all.
            guard !isRecoveringPastedToken else { return }
            isRecoveringPastedToken = true
            defer { isRecoveringPastedToken = false }
            guard accessToken != lastRejectedToken else {
                lastError = "Token rejected again — paste a fresh one and press return."
                return
            }
            lastRejectedToken = accessToken
        }

        await TrustSignalsSDK.scheduleCollections(scheduledRequests(accountsWithToken(armedAccounts)))
        tokenRecoveries += 1
        await refreshScheduleState()
    }

    func collectNow() async {
        isBusy = true
        lastError = nil
        do {
            collectOnly.insert(try await TrustSignalsSDK.collect().collectionId)
        } catch {
            lastError =  Self.reason(for: error)
        }
        isBusy = false
    }

    func collectAndUpload() async {
        let accounts = parsedAccountIds
        guard !accounts.isEmpty else {
            lastError = "Enter at least one account ID."
            return
        }
        let ready = accounts.filter { !token(for: $0).isEmpty }
        lastError = missingTokenMessage(for: accounts.subtracting(ready))
        guard !ready.isEmpty else { return }
        isBusy = true
        do {
            let outcome = try await TrustSignalsSDK.collectAndUpload(
                ready.map { credentials(accountId: $0) }
            )
            // The outcome names both sides, so the grid gets its successes from here.
            // A scheduled cycle has no equivalent — there only failures are reported.
            for (accountId, collection) in outcome.uploaded {
                uploads[collection.collectionId, default: [:]][accountId] =
                    UploadOutcome(isSuccess: true, detail: "accepted by BE")
            }
            if !outcome.allSucceeded {
                lastError = outcome.failures
                    .map { "\($0.key): \(Self.reason(for: $0.value))" }
                    .sorted()
                    .joined(separator: "\n")
            }
        } catch let uploadError as TSUploadError {
            // Nothing got through at all — same per-account detail as a partial
            // failure, just via the thrown error instead of the returned outcome.
            lastError = uploadError.failures
                .map { "\($0.key): \(Self.reason(for: $0.value))" }
                .sorted()
                .joined(separator: "\n")
        } catch {
            lastError = Self.reason(for: error)
        }
        isBusy = false
    }

    func interval(for accountId: String) -> Int {
        intervals[accountId] ?? Self.defaultIntervalSeconds
    }

    func setInterval(_ seconds: Int, for accountId: String) async {
        intervals[accountId] = seconds
        await applySchedule()
    }

    func setIntervalForAllAccounts(_ seconds: Int) async {
        for accountId in parsedAccountIds {
            intervals[accountId] = seconds
        }
        await applySchedule()
    }

    func syncIntervalsWithEnteredAccounts() {
        let accounts = parsedAccountIds
        for accountId in accounts where intervals[accountId] == nil {
            intervals[accountId] = Self.defaultIntervalSeconds
        }
        for accountId in intervals.keys where !accounts.contains(accountId) {
            intervals[accountId] = nil
        }
    }

    func armedSeconds(for accountId: String) -> Int? {
        schedules[accountId].map { Int($0.components.seconds) }
    }

    var armedAccounts: [String: Duration] {
        parsedAccountIds.reduce(into: [String: Duration]()) { armed, accountId in
            let seconds = interval(for: accountId)
            if seconds > 0 { armed[accountId] = .seconds(Double(seconds)) }
        }
    }

    func applySchedule() async {
        let accounts = armedAccounts
        let ready = accountsWithToken(accounts)
        lastError = missingTokenMessage(for: Set(accounts.keys).subtracting(ready.keys))
        guard !ready.isEmpty else {
            await TrustSignalsSDK.stopScheduledCollections()
            await refreshScheduleState()
            return
        }
        lastRejectedToken = nil
        tokenFetchedInRecovery = [:]
        // The array form stops every account missing from it — including one that just
        // lost its token.
        await TrustSignalsSDK.scheduleCollections(scheduledRequests(ready))
        await refreshScheduleState()
    }

    /// Validates the override, fetches its token, and only then saves and applies it —
    /// an override whose credentials don't produce a token must not replace the
    /// account's working identity, now or at the next launch.
    /// - Returns: why it was not saved, or `nil` on success.
    func saveOverride(_ draft: ClientOverride, for accountId: String) async -> String? {
        let candidate = ClientOverride(
            clientId: trimmed(draft.clientId),
            clientSecret: trimmed(draft.clientSecret),
            serviceId: trimmed(draft.serviceId),
            authBaseURL: trimmed(draft.authBaseURL)
        )
        guard !candidate.clientId.isEmpty, !candidate.clientSecret.isEmpty, !candidate.serviceId.isEmpty else {
            return "Client ID, client secret and service ID must be set together — the client "
                + "credentials are issued for one specific service ID. Fill in all three, or remove the override."
        }
        guard UUID(uuidString: candidate.serviceId) != nil else {
            return "Service ID must be a canonical UUID, e.g. 3F7C1E2A-9B4D-4F80-A1C6-5D2E8B0F3A91."
        }
        guard URL(string: candidate.authBaseURL)?.host != nil else {
            return "Auth server URL is not a valid URL."
        }
        let token: OAuthTokenClient.Token
        do {
            token = try await OAuthTokenClient.fetchToken(for: candidate)
        } catch {
            return "Token fetch failed — \(error.localizedDescription)"
        }
        do {
            try ClientOverrideStore.save(candidate, for: accountId)
        } catch {
            return "Could not save the override: \(error.localizedDescription)"
        }
        overrides[accountId] = candidate
        store(token, for: accountId)
        await applySchedule()
        return nil
    }

    /// Drops the account's override: back to the pasted token and the launch Service ID.
    func removeOverride(for accountId: String) async {
        ClientOverrideStore.clear(for: accountId)
        overrides[accountId] = nil
        overrideTokens[accountId] = nil
        tokenStatuses[accountId] = nil
        await applySchedule()
    }

    /// Fetches a fresh token for the account's override.
    func refreshToken(for accountId: String) async {
        guard let override = overrides[accountId] else { return }
        if await fetchToken(for: accountId, override: override) {
            await applySchedule()
        }
    }

    /// - Returns: `true` when a token was fetched.
    @discardableResult
    private func fetchToken(for accountId: String, override: ClientOverride) async -> Bool {
        do {
            store(try await OAuthTokenClient.fetchToken(for: override), for: accountId)
            return true
        } catch {
            overrideTokens[accountId] = nil
            tokenStatuses[accountId] = nil
            lastError = "\(accountId): token fetch failed — \(error.localizedDescription)"
            return false
        }
    }

    private func store(_ token: OAuthTokenClient.Token, for accountId: String) {
        overrideTokens[accountId] = token.accessToken
        tokenStatuses[accountId] = "Token fetched \(Date().formatted(date: .omitted, time: .standard))"
            + (token.expiresIn.map { ", expires in \($0)s" } ?? "")
    }

    /// The account's own token when it has an override, the pasted one otherwise.
    private func token(for accountId: String) -> String {
        hasOverride(accountId) ? (overrideTokens[accountId] ?? "") : trimmed(accessToken)
    }

    private func accountsWithToken(_ accounts: [String: Duration]) -> [String: Duration] {
        accounts.filter { !token(for: $0.key).isEmpty }
    }

    private func missingTokenMessage(for accounts: Set<String>) -> String? {
        guard !accounts.isEmpty else { return nil }
        return "No access token for \(accounts.sorted().joined(separator: ", ")) — paste one, "
            + "or configure a client override for the account. Skipped."
    }

    /// The single place credentials are built, so an on-demand upload and a scheduled
    /// one always carry the same identity.
    private func credentials(accountId: String) -> TSCredentials {
        TSCredentials(
            accountId: accountId,
            accessToken: token(for: accountId),
            serviceId: serviceId(for: accountId),
            unitId: unitId,
            interactionId: trimmed(interactionId),
            verificationStatus: verificationStatus
        )
    }

    private func trimmed(_ value: String) -> String {
        value.trimmingCharacters(in: .whitespacesAndNewlines)
    }

    private func scheduledRequests(_ accounts: [String: Duration]) -> [TSScheduledRequest] {
        accounts.map { accountId, interval in
            TSScheduledRequest(credentials: credentials(accountId: accountId), collectionInterval: interval)
        }
    }

    func stopScheduledCollections() async {
        for accountId in intervals.keys {
            intervals[accountId] = 0
        }
        await TrustSignalsSDK.stopScheduledCollections()
        await refreshScheduleState()
    }

    func refreshScheduleState() async {
        schedules = await TrustSignalsSDK.schedules
    }

    var parsedAccountIds: Set<String> {
        Set(
            accountIds
                .split(whereSeparator: { $0 == "," || $0 == " " || $0 == "\n" })
                .map { $0.trimmingCharacters(in: .whitespaces) }
                .filter { !$0.isEmpty }
        )
    }

    private func append(_ collection: TSCollection) {
        collections.insert(collection, at: 0)
    }

    deinit {
        observerTask?.cancel()
    }
}

/// The per-installation identifier sent as `interactionId`.
///
/// This lives in the host app, not the SDK — the SDK generates no identity fields, so
/// minting and storing this value is the integrator's job. A real host would do exactly
/// what this does.
///
/// `UserDefaults` rather than the keychain, because the value is scoped to an
/// *installation*: keychain entries outlive app deletion, which would make it
/// per-device-forever and unclearable by the user. Defaults go away with the app.
enum InstallationIdentifier {

    private static let key = "com.futurae.trustsignalstestapp.installationID"

    /// Returns the stored identifier, minting and persisting one on first launch.
    static func loadOrCreate() -> String {
        if let stored = UserDefaults.standard.string(forKey: key),
           !stored.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
            return stored
        }
        let fresh = UUID().uuidString
        save(fresh)
        return fresh
    }

    static func save(_ value: String) {
        UserDefaults.standard.set(value, forKey: key)
    }
}

// MARK: - OAuth2 client override

/// Client ID, client secret and the service ID they were issued for — always together.
struct ClientOverride: Equatable, Sendable {
    let clientId: String
    let clientSecret: String
    let serviceId: String
    let authBaseURL: String
}

/// Persists each account's override: the secret in the keychain, keyed by account, the
/// rest in `UserDefaults`.
enum ClientOverrideStore {

    private static let defaultsKey = "com.futurae.trustsignalstestapp.clientOverrides"
    private static let keychainService = "com.futurae.trustsignalstestapp.clientSecret"

    private struct Stored: Codable {
        let clientId: String
        let serviceId: String
        let authBaseURL: String
    }

    struct KeychainError: LocalizedError {
        let status: OSStatus
        var errorDescription: String? { "keychain error \(status)" }
    }

    static func loadAll() -> [String: ClientOverride] {
        storedEntries().reduce(into: [:]) { overrides, entry in
            guard let secret = readSecret(for: entry.key) else { return }
            overrides[entry.key] = ClientOverride(
                clientId: entry.value.clientId,
                clientSecret: secret,
                serviceId: entry.value.serviceId,
                authBaseURL: entry.value.authBaseURL
            )
        }
    }

    static func save(_ override: ClientOverride, for accountId: String) throws {
        try writeSecret(override.clientSecret, for: accountId)
        var entries = storedEntries()
        entries[accountId] = Stored(clientId: override.clientId, serviceId: override.serviceId, authBaseURL: override.authBaseURL)
        UserDefaults.standard.set(try JSONEncoder().encode(entries), forKey: defaultsKey)
    }

    static func clear(for accountId: String) {
        var entries = storedEntries()
        entries[accountId] = nil
        UserDefaults.standard.set(try? JSONEncoder().encode(entries), forKey: defaultsKey)
        SecItemDelete(secretQuery(for: accountId) as CFDictionary)
    }

    private static func storedEntries() -> [String: Stored] {
        guard let data = UserDefaults.standard.data(forKey: defaultsKey),
              let entries = try? JSONDecoder().decode([String: Stored].self, from: data) else { return [:] }
        return entries
    }

    private static func secretQuery(for accountId: String) -> [String: Any] {
        [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrService as String: keychainService,
            kSecAttrAccount as String: accountId,
        ]
    }

    private static func readSecret(for accountId: String) -> String? {
        var query = secretQuery(for: accountId)
        query[kSecReturnData as String] = true
        query[kSecMatchLimit as String] = kSecMatchLimitOne
        var result: AnyObject?
        guard SecItemCopyMatching(query as CFDictionary, &result) == errSecSuccess,
              let data = result as? Data else { return nil }
        return String(data: data, encoding: .utf8)
    }

    private static func writeSecret(_ secret: String, for accountId: String) throws {
        SecItemDelete(secretQuery(for: accountId) as CFDictionary)
        var item = secretQuery(for: accountId)
        item[kSecValueData as String] = Data(secret.utf8)
        item[kSecAttrAccessible as String] = kSecAttrAccessibleAfterFirstUnlockThisDeviceOnly
        let status = SecItemAdd(item as CFDictionary, nil)
        guard status == errSecSuccess else { throw KeychainError(status: status) }
    }
}

/// OAuth2 client-credentials grant against the authorization server, for the
/// observation-upload token.
enum OAuthTokenClient {

    /// The `tscollection` project audience.
    private static let writeScope = "urn:zitadel:iam:org:project:id:tscollection:aud"

    struct Token: Decodable, Sendable {
        let accessToken: String
        let expiresIn: Int?

        enum CodingKeys: String, CodingKey {
            case accessToken = "access_token"
            case expiresIn = "expires_in"
        }
    }

    struct TokenError: LocalizedError {
        let message: String
        var errorDescription: String? { message }
    }

    static func fetchToken(for override: ClientOverride) async throws -> Token {
        guard let base = URL(string: override.authBaseURL) else {
            throw TokenError(message: "invalid auth server URL")
        }
        var request = URLRequest(url: base.appendingPathComponent("oauth/v2/token"))
        request.httpMethod = "POST"
        request.setValue("application/x-www-form-urlencoded", forHTTPHeaderField: "Content-Type")
        request.setValue("application/json", forHTTPHeaderField: "Accept")
        let basic = Data("\(override.clientId):\(override.clientSecret)".utf8).base64EncodedString()
        request.setValue("Basic \(basic)", forHTTPHeaderField: "Authorization")
        var body = URLComponents()
        body.queryItems = [
            URLQueryItem(name: "grant_type", value: "client_credentials"),
            URLQueryItem(name: "scope", value: writeScope),
        ]
        request.httpBody = body.percentEncodedQuery?.data(using: .utf8)

        let (data, response) = try await URLSession.shared.data(for: request)
        guard let http = response as? HTTPURLResponse else {
            throw TokenError(message: "non-HTTP response")
        }
        guard (200..<300).contains(http.statusCode) else {
            let detail = String(data: data, encoding: .utf8).map { " — \($0.prefix(120))" } ?? ""
            throw TokenError(message: "HTTP \(http.statusCode)\(detail)")
        }
        return try JSONDecoder().decode(Token.self, from: data)
    }
}
