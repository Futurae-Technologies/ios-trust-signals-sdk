import SwiftUI
import TrustSignals

/// Main screen — shows the running list of collections, lets the host
/// trigger an on-demand collection, change the schedule, or stop the SDK.
struct CollectionsView: View {
    @StateObject private var store = CollectionStore()

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

                        Spacer()

                        Button {
                            Task { await store.collectAndUpload() }
                        } label: {
                            Label("Collect & Upload", systemImage: "icloud.and.arrow.up")
                        }
                        .buttonStyle(.borderless)
                        .disabled(store.isBusy)

                        Spacer()

                        if store.isBusy {
                            ProgressView()
                        }
                    }

                    TextField("Account ID", text: $store.accountID)
                        .textInputAutocapitalization(.never)
                        .autocorrectionDisabled()
                    TextField("OAuth2 access token", text: $store.accessToken)
                        .textInputAutocapitalization(.never)
                        .autocorrectionDisabled()
                        .font(.caption.monospaced())

                    HStack {
                        Text("Schedule")
                        Spacer()
                        Picker("", selection: $store.scheduleSeconds) {
                            Text("Manual").tag(0)
                            Text("10 s").tag(10)
                            Text("15 s").tag(15)
                            Text("30 s").tag(30)
                            Text("60 s").tag(60)
                            Text("5 min").tag(300)
                            Text("10 min").tag(600)
                            Text("30 min").tag(1800)
                            Text("60 min").tag(3600)
                        }
                        .pickerStyle(.menu)
                    }

                    if let err = store.lastError {
                        Label(err, systemImage: "exclamationmark.triangle.fill")
                            .foregroundStyle(.orange)
                            .font(.caption)
                    }
                }

                Section("Collections (\(store.collections.count))") {
                    if store.collections.isEmpty {
                        Text("No collections yet — tap Collect Now")
                            .foregroundStyle(.secondary)
                            .font(.caption)
                    } else {
                        ForEach(store.collections) { c in
                            NavigationLink(value: c.collectionId) {
                                CollectionRow(collection: c)
                            }
                        }
                    }
                }
            }
            .navigationTitle("Trust Signals")
            .navigationDestination(for: UUID.self) { id in
                if let collection = store.collections.first(where: { $0.collectionId == id }) {
                    CollectionDetailView(collection: collection)
                } else {
                    ContentUnavailableView(
                        "Collection no longer in memory",
                        systemImage: "questionmark.folder",
                        description: Text("It may have been dropped after a tab restart.")
                    )
                }
            }
            .task { await store.startObserving() }
            .onChange(of: store.scheduleSeconds) { _, newValue in
                Task { await store.applySchedule(seconds: newValue) }
            }
        }
    }
}

private struct CollectionRow: View {
    let collection: TSCollection

    var body: some View {
        VStack(alignment: .leading, spacing: 4) {
            HStack {
                Image(systemName: "clock")
                    .foregroundStyle(.secondary)
                Text(formattedTimestamp)
                    .font(.subheadline)
                    .monospaced()
                Spacer()
                Text(collection.tag.uppercased())
                    .font(.caption)
                    .foregroundStyle(.secondary)
                    .padding(.horizontal, 6)
                    .padding(.vertical, 2)
                    .background(Color.secondary.opacity(0.15), in: Capsule())
            }
            HStack(spacing: 12) {
                Stat(label: "BLE", value: "\(collection.observation.bleScan?.scanResults.count ?? 0)",
                     granted: collection.observation.bleScan?.permission)
                Stat(label: "WiFi", value: collection.observation.wifiNetwork?.name ?? "—",
                     granted: collection.observation.wifiScan?.permission)
                Stat(label: "Loc", value: collection.observation.locationCollection.map { "\(format($0.lat)),\(format($0.lon))" } ?? "—",
                     granted: collection.observation.locationCollection != nil)
                Stat(label: "Near", value: "\(collection.observation.nearbyDevices.count)",
                     granted: nil)
                Stat(label: "Call", value: collection.observation.activeCall.map { $0 ? "yes" : "no" } ?? "—",
                     granted: nil)
            }
            Text("id \(collection.collectionId.uuidString.prefix(8))…")
                .font(.caption2)
                .foregroundStyle(.tertiary)
                .monospaced()
        }
        .padding(.vertical, 2)
    }

    private var formattedTimestamp: String {
        let date = Date(timeIntervalSince1970: TimeInterval(collection.timestamp))
        return date.formatted(date: .abbreviated, time: .standard)
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
