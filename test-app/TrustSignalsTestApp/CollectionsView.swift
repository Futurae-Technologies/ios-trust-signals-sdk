import SwiftUI
import TrustSignals

/// Main screen — shows the running list of collections, lets the host
/// trigger an on-demand collection, change the schedule, or stop the SDK.
struct CollectionsView: View {

    @StateObject private var store: CollectionStore

    init(settings: LaunchSettings) {
        _store = StateObject(wrappedValue: CollectionStore(settings: settings))
    }
    @State private var bulkInterval: Int = 0
    @State private var editingAccount: EditingAccount?

    private struct EditingAccount: Identifiable {
        let id: String
    }

    var body: some View {
        NavigationStack {
            List {
                Section {
                    HStack {
                        Button {
                            Task { await store.collectNow() }
                        } label: {
                            Label("Collect Now", systemImage: "scope")
                        }
                        .buttonStyle(.borderless)
                        .disabled(store.isBusy)
                        .accessibilityIdentifier("collect_now")

                        Spacer()

                        Button {
                            Task { await store.collectAndUpload() }
                        } label: {
                            Label("Collect & Upload", systemImage: "icloud.and.arrow.up")
                        }
                        .buttonStyle(.borderless)
                        .disabled(store.isBusy)
                        .accessibilityIdentifier("collect_and_upload")

                        Spacer()

                        if store.isBusy {
                            ProgressView()
                        }
                    }
                    CaptionedTextField("Interaction ID (per installation)", text: $store.interactionId, accessibilityIdentifier: "interactionid_input")
                        .textInputAutocapitalization(.never)
                        .autocorrectionDisabled()
                        .onSubmit { Task { await store.applySchedule() } }

                    VStack(alignment: .leading, spacing: 6) {
                        Text("Verification Status")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                        Picker("Verification status", selection: $store.verificationStatus) {
                            Text("unverified").tag(TSVerificationStatus.unverified)
                                .accessibilityIdentifier("verification_status_option_unverified")
                            Text("verified").tag(TSVerificationStatus.verified)
                                .accessibilityIdentifier("verification_status_option_verified")
                            Text("fraud").tag(TSVerificationStatus.fraud)
                                .accessibilityIdentifier("verification_status_option_fraud")
                        }
                        .pickerStyle(.segmented)
                        .accessibilityIdentifier("verification_status_option")
                        .onChange(of: store.verificationStatus) { _ in
                            Task { await store.applySchedule() }
                        }
                        // A real host derives this from its enrollment state; a sample
                        // app has none, so the picker stands in for it.
                        Text("unverified — fresh install, pre-enrollment, or after logout. verified — device bound to an account. fraud — TBD. Whichever is selected here is the value sent as verificationStatus in the uploaded JSON.")
                            .font(.caption2)
                            .foregroundStyle(.secondary)
                            .accessibilityIdentifier("verification_status_help")
                    }

                    CaptionedTextField("Account IDs (comma separated)", text: $store.accountIds, accessibilityIdentifier: "accountid_input")
                        .textInputAutocapitalization(.never)
                        .autocorrectionDisabled()
                        .onSubmit { Task { await store.applySchedule() } }
                    CaptionedTextField("OAuth2 access token", text: $store.accessToken, accessibilityIdentifier: "access_token_input")
                        .textInputAutocapitalization(.never)
                        .autocorrectionDisabled()
                        .onSubmit { Task { await store.applySchedule() } }

                    VStack(alignment: .leading, spacing: 6) {
                        Text("Scheduled Collection Frequency")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                        Picker("Collection frequency", selection: $bulkInterval) {
                            Text("Off").tag(0)
                                .accessibilityIdentifier("frequency_option_off")
                            Text("30s").tag(30)
                                .accessibilityIdentifier("frequency_option_thirtyseconds")
                            Text("3m").tag(180)
                                .accessibilityIdentifier("frequency_option_threeminutes")
                            Text("7m").tag(420)
                                .accessibilityIdentifier("frequency_option_sevenminutes")
                        }
                        .pickerStyle(.segmented)
                        .accessibilityIdentifier("frequency_option")
                        .disabled(store.parsedAccountIds.isEmpty)
                        .onChange(of: bulkInterval) { newValue in
                            Task { await store.setIntervalForAllAccounts(newValue) }
                        }
                    }

                    if store.tokenRecoveries > 0 {
                        LabeledContent("Token re-arms") {
                            Text("\(store.tokenRecoveries)")
                                .font(.caption.monospaced())
                        }
                    }

                    if let err = store.lastError {
                        Label(err, systemImage: "exclamationmark.triangle.fill")
                            .foregroundStyle(.orange)
                            .font(.caption)
                    }
                }

                Section {
                    EnvelopeValueRow(
                        key: "serviceId",
                        value: store.settings.serviceId,
                        source: "from launch",
                        accessibilityIdentifier: "envelope_serviceid"
                    )
                    EnvelopeValueRow(
                        key: "unitId",
                        value: store.unitId,
                        source: "from launch",
                        accessibilityIdentifier: "envelope_unitid"
                    )
                } header: {
                    Text("Sent in every upload envelope")
                } footer: {
                    Text("Defaults for every account. An account with a client override sends its own serviceId and token instead — see Accounts below.")
                        .font(.caption2)
                }

                if !store.parsedAccountIds.isEmpty {
                    Section {
                        ForEach(store.parsedAccountIds.sorted(), id: \.self) { accountId in
                            HStack {
                                VStack(alignment: .leading, spacing: 2) {
                                    Text(accountId)
                                        .font(.caption.monospaced())
                                    Text("serviceId \(store.serviceId(for: accountId))")
                                        .font(.caption2.monospaced())
                                        .foregroundStyle(.secondary)
                                        .accessibilityIdentifier("account_serviceid_\(accountId)")
                                    Button {
                                        editingAccount = EditingAccount(id: accountId)
                                    } label: {
                                        Label(
                                            store.hasOverride(accountId) ? "Client override — active" : "Configure client",
                                            systemImage: store.hasOverride(accountId) ? "key.fill" : "key"
                                        )
                                        .font(.caption2)
                                    }
                                    .buttonStyle(.borderless)
                                    .accessibilityIdentifier("configure_client_\(accountId)")
                                    if let armed = store.armedSeconds(for: accountId) {
                                        Label("Collect and upload: every \(armed)s", systemImage: "checkmark.circle.fill")
                                            .font(.caption2)
                                            .foregroundStyle(.green)
                                    } else {
                                        Label("not armed", systemImage: "circle.dashed")
                                            .font(.caption2)
                                            .foregroundStyle(.secondary)
                                    }
                                }
                                Spacer()
                                Picker("", selection: Binding(
                                    get: { store.interval(for: accountId) },
                                    set: { seconds in Task { await store.setInterval(seconds, for: accountId) } }
                                )) {
                                    Text("Off").tag(0)
                                    Text("30 s").tag(30)
                                    Text("60 s").tag(60)
                                    Text("90 s").tag(90)
                                    Text("2 min").tag(120)
                                    Text("3 min").tag(180)
                                    Text("5 min").tag(300)
                                    Text("7 min").tag(420)
                                    Text("30 min").tag(1800)
                                }
                                .pickerStyle(.menu)
                            }
                        }
                    } header: {
                        Text("Accounts")
                    } footer: {
                        Text("""
                        Picking an interval arms that account straight away — there is nothing to \
                        confirm — and Off disarms it. Each account needs an access token — its own \
                        client override's, or the pasted one: an account without one is skipped.

                        Each account then collects and uploads on its own deadline, independently \
                        of the others. Whether accounts due at the same moment share one sensor \
                        sweep depends on the reuse window chosen at launch — zero by default, so \
                        every account sweeps for itself.
                        """)
                            .font(.caption2)
                    }
                }

                Section {
                    if store.collections.isEmpty {
                        Text("No collections yet — tap Collect Now")
                            .foregroundStyle(.secondary)
                            .font(.caption)
                            .accessibilityIdentifier("collection_empty_state")
                    } else {
                        ForEach(Array(store.collections.enumerated()), id: \.element.collectionId) { index, c in
                            NavigationLink(value: c.collectionId) {
                                CollectionRow(
                                    collection: c,
                                    uploads: store.uploads[c.collectionId] ?? [:],
                                    isCollectOnly: store.collectOnly.contains(c.collectionId)
                                )
                            }
                            .accessibilityIdentifier("collection_item_\(index)")
                        }
                        .accessibilityIdentifier("collection_list")
                    }
                } header: {
                    VStack(alignment: .leading, spacing: 2) {
                        Text("Collections (\(store.collections.count))")
                            .accessibilityIdentifier("collections_count")
                        Text("A scheduled cycle reports only failures, so a row with no result means it was not rejected.")
                            .font(.caption2)
                            .textCase(nil)
                    }
                }
            }
            .navigationTitle("Trust Signals")
            .navigationDestination(for: UUID.self) { id in
                if let collection = store.collections.first(where: { $0.collectionId == id }) {
                    CollectionDetailView(
                        collection: collection,
                        accountId: store.parsedAccountIds.sorted().joined(separator: ", "),
                        serviceId: store.previewServiceId,
                        unitId: store.unitId,
                        interactionId: store.interactionId.trimmingCharacters(in: .whitespacesAndNewlines),
                        verificationStatus: store.verificationStatus
                    )
                } else {
                    MissingCollectionView()
                }
            }
            .task { await store.startObserving() }
            .sheet(item: $editingAccount) { account in
                ClientOverrideEditor(accountId: account.id, store: store)
            }
            .onChange(of: store.accountIds) { _ in
                store.syncIntervalsWithEnteredAccounts()
            }
        }
    }
}

private struct CollectionRow: View {
    let collection: TSCollection
    let uploads: [String: CollectionStore.UploadOutcome]
    let isCollectOnly: Bool

    var body: some View {
        VStack(alignment: .leading, spacing: 4) {
            HStack {
                Image(systemName: "clock")
                    .foregroundStyle(.secondary)
                Text(formattedTimestamp)
                    .font(.subheadline)
                    .monospaced()
                Spacer()
                Text(collection.sensorTag.uppercased())
                    .font(.caption)
                    .foregroundStyle(.secondary)
                    .padding(.horizontal, 6)
                    .padding(.vertical, 2)
                    .background(Color.secondary.opacity(0.15), in: Capsule())
            }
            HStack(spacing: 12) {
                Stat(label: "BLE", value: "\(collection.observation.bleScan?.scanResults.count ?? 0)",
                     granted: collection.observation.bleScan?.permissionGranted)
                Stat(label: "WiFi", value: collection.observation.wifiNetwork?.name ?? "—",
                     granted: collection.observation.wifiScan?.permissionGranted)
                Stat(label: "Loc", value: collection.observation.location.map { "\(format($0.lat)),\(format($0.lon))" } ?? "—",
                     granted: collection.observation.location != nil)
                Stat(label: "Near", value: "\(collection.observation.nearbyDevices.count)",
                     granted: nil)
                Stat(label: "Call", value: collection.observation.activeCall.map { $0 ? "yes" : "no" } ?? "—",
                     granted: nil)
                Stat(label: "Net", value: collection.observation.networkState.map { $0.vpnActive ? "\($0.networkType)+VPN" : $0.networkType } ?? "—",
                     granted: nil)
            }
            Text("id \(collection.collectionId.uuidString.prefix(8))…")
                .font(.caption2)
                .foregroundStyle(.tertiary)
                .monospaced()

            if uploads.isEmpty {
                Label(
                    isCollectOnly ? "collect only — never uploaded" : "no upload result",
                    systemImage: "circle.dashed"
                )
                    .font(.caption2)
                    .foregroundStyle(.secondary)
            } else {
                HStack(spacing: 8) {
                    ForEach(uploads.keys.sorted(), id: \.self) { accountId in
                        let outcome = uploads[accountId]!
                        Label(accountId, systemImage: outcome.isSuccess ? "checkmark.icloud.fill" : "exclamationmark.icloud.fill")
                            .font(.caption2)
                            .foregroundStyle(outcome.isSuccess ? .green : .orange)
                            .lineLimit(1)
                    }
                }
            }
        }
        .padding(.vertical, 2)
    }

    private var formattedTimestamp: String {
        collection.observationTime.formatted(date: .abbreviated, time: .standard)
    }

    private func format(_ value: Double) -> String {
        String(format: "%.4f", value)
    }
}

private struct Stat: View {
    let label: String
    let value: String
    /// `true` = granted, `false` = denied, `nil` = unknown / not applicable.
    let granted: Bool?

    var body: some View {
        VStack(alignment: .leading, spacing: 1) {
            HStack(spacing: 3) {
                Text(label)
                    .font(.caption2.bold())
                    .foregroundStyle(.secondary)
                if let granted {
                    Image(systemName: granted ? "checkmark.circle.fill" : "lock.slash.fill")
                        .font(.caption2)
                        .foregroundStyle(granted ? .green : .red)
                }
            }
            Text(value)
                .font(.caption2)
                .monospaced()
                .lineLimit(1)
                .truncationMode(.middle)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }
}

private struct MissingCollectionView: View {
    var body: some View {
        VStack(spacing: 8) {
            Image(systemName: "questionmark.folder")
                .font(.largeTitle)
                .foregroundStyle(.secondary)
            Text("Collection no longer in memory")
                .font(.headline)
            Text("It may have been dropped after a tab restart.")
                .font(.subheadline)
                .foregroundStyle(.secondary)
                .multilineTextAlignment(.center)
        }
        .padding()
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }
}

/// Edits one account's client override: client ID, client secret and the service ID they
/// were issued for, always together. Saving fetches the token first, so a client that
/// cannot produce one never replaces the account's working identity.
private struct ClientOverrideEditor: View {
    let accountId: String
    @ObservedObject var store: CollectionStore

    @Environment(\.dismiss) private var dismiss
    @State private var clientId = ""
    @State private var clientSecret = ""
    @State private var serviceId = ""
    @State private var authBaseURL = ""
    @State private var error: String?
    @State private var isWorking = false

    var body: some View {
        NavigationStack {
            Form {
                Section {
                    CaptionedTextField("Client ID", text: $clientId, accessibilityIdentifier: "client_id_input")
                        .textInputAutocapitalization(.never)
                        .autocorrectionDisabled()
                    CaptionedTextField("Client secret", text: $clientSecret, isSecure: true, accessibilityIdentifier: "client_secret_input")
                        .textInputAutocapitalization(.never)
                        .autocorrectionDisabled()
                    CaptionedTextField("Service ID (UUID)", text: $serviceId, accessibilityIdentifier: "override_serviceid_input")
                        .textInputAutocapitalization(.never)
                        .autocorrectionDisabled()
                    CaptionedTextField("Auth server URL", text: $authBaseURL, accessibilityIdentifier: "auth_base_url_input")
                        .textInputAutocapitalization(.never)
                        .autocorrectionDisabled()
                        .keyboardType(.URL)
                } header: {
                    Text(store.hasOverride(accountId) ? "Client override — active" : "Client override — off")
                        .accessibilityIdentifier("override_header")
                } footer: {
                    Text("""
                    Applies to every upload of \(accountId) — on demand and scheduled: it sends \
                    this service ID with a token fetched for this client (client-credentials grant). \
                    Client ID, client secret and service ID go together — the client credentials \
                    are issued for one specific service ID, so a partial override would be rejected \
                    with a 403. A rejected token is refreshed automatically. Unit ID comes from \
                    launch and cannot be changed here.
                    """)
                        .font(.caption2)
                }

                if let status = store.tokenStatus(for: accountId) {
                    Section {
                        Label(status, systemImage: "key.fill")
                            .font(.caption2)
                            .foregroundStyle(.secondary)
                            .accessibilityIdentifier("token_status")
                    }
                }

                if let error {
                    Section {
                        Label(error, systemImage: "exclamationmark.triangle.fill")
                            .foregroundStyle(.orange)
                            .font(.caption)
                    }
                }

                if store.hasOverride(accountId) {
                    Section {
                        Button("Refresh Token") {
                            Task {
                                isWorking = true
                                await store.refreshToken(for: accountId)
                                isWorking = false
                            }
                        }
                        .accessibilityIdentifier("refresh_token")
                        Button("Remove Override", role: .destructive) {
                            Task {
                                await store.removeOverride(for: accountId)
                                dismiss()
                            }
                        }
                        .accessibilityIdentifier("remove_override")
                    }
                }
            }
            .disabled(isWorking)
            .navigationTitle(accountId)
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") { dismiss() }
                }
                ToolbarItem(placement: .confirmationAction) {
                    if isWorking {
                        ProgressView()
                    } else {
                        Button("Save") { Task { await save() } }
                            .accessibilityIdentifier("save_override")
                    }
                }
            }
            .onAppear {
                let draft = store.draftOverride(for: accountId)
                clientId = draft.clientId
                clientSecret = draft.clientSecret
                serviceId = draft.serviceId
                authBaseURL = draft.authBaseURL
            }
        }
    }

    private func save() async {
        isWorking = true
        error = await store.saveOverride(
            ClientOverride(clientId: clientId, clientSecret: clientSecret, serviceId: serviceId, authBaseURL: authBaseURL),
            for: accountId
        )
        isWorking = false
        if error == nil { dismiss() }
    }
}

/// One top-level field of the upload body, shown in full so it can be read and copied.
private struct EnvelopeValueRow: View {
    let key: String
    let value: String
    let source: String
    let accessibilityIdentifier: String

    var body: some View {
        VStack(alignment: .leading, spacing: 2) {
            HStack {
                Text(key)
                    .font(.caption2.monospaced())
                    .foregroundStyle(.secondary)
                Spacer()
                Text(source)
                    .font(.caption2)
                    .foregroundStyle(.secondary)
            }
            Text(value.isEmpty ? "not set" : value)
                .font(.caption.monospaced())
                .foregroundStyle(value.isEmpty ? .orange : .primary)
                .textSelection(.enabled)
                .fixedSize(horizontal: false, vertical: true)
                .accessibilityIdentifier(accessibilityIdentifier)
        }
    }
}

/// A text field whose placeholder stays visible as a caption above it once the field
/// holds a value — typed by the tester or filled in as a default — so a filled-in form
/// still says what each value is. Owns its font, so every field in the app looks the
/// same: identifiers, UUIDs, URLs and tokens all read best monospaced.
struct CaptionedTextField: View {
    let title: String
    @Binding var text: String
    var isSecure = false
    var accessibilityIdentifier: String?

    init(
        _ title: String,
        text: Binding<String>,
        isSecure: Bool = false,
        accessibilityIdentifier: String? = nil
    ) {
        self.title = title
        self._text = text
        self.isSecure = isSecure
        self.accessibilityIdentifier = accessibilityIdentifier
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 2) {
            if !text.isEmpty {
                Text(title)
                    .font(.caption2)
                    .foregroundStyle(.secondary)
                    .accessibilityIdentifier(ifPresent: accessibilityIdentifier.map { "\($0)_label" })
            }
            field
                .font(.caption.monospaced())
                .accessibilityIdentifier(ifPresent: accessibilityIdentifier)
        }
    }

    @ViewBuilder
    private var field: some View {
        if isSecure {
            SecureField(title, text: $text)
        } else {
            TextField(title, text: $text)
        }
    }
}

private extension View {
    @ViewBuilder
    func accessibilityIdentifier(ifPresent identifier: String?) -> some View {
        if let identifier {
            accessibilityIdentifier(identifier)
        } else {
            self
        }
    }
}
