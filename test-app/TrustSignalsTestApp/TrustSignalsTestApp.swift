import SwiftUI
import TrustSignals

enum TestAppConfig {
    static let backgroundTaskIdentifier = "com.futurae.trustsignals.refresh"

    // Defaults for the launch screen and the client override.
    static let defaultCollectionBaseURL = GeneratedConfig.tsBaseURL
    static let defaultAuthBaseURL = GeneratedConfig.tsAuthBaseURL
    static let defaultServiceId = GeneratedConfig.tsServiceId
    static let defaultUnitId = GeneratedConfig.tsUnitId
    static let defaultClientId = GeneratedConfig.tsClientId
    static let defaultClientSecret = GeneratedConfig.tsClientSecret

    /// The SDK takes the full endpoint; the test-app is configured with the host.
    static func collectionUrl(baseURL: URL) -> URL {
        baseURL.appendingPathComponent("api/v1/collections", isDirectory: false)
    }
}

struct LaunchSettings {
    let collectionUrl: URL
    let authBaseURL: String
    /// Identity defaults for every account's `TSCredentials`; the SDK configuration
    /// carries no identifiers.
    let serviceId: String
    let unitId: String
    let sensorTag: String
    let reuseWindowSeconds: Int

    var configuration: TSConfiguration {
        TSConfiguration(
            collectionUrl: collectionUrl,
            sensorTag: sensorTag,
            collectionReuseWindow: .seconds(Double(reuseWindowSeconds))
        )
    }
}

@main
struct TrustSignalsTestApp: App {
    @State private var launched: LaunchSettings?

    nonisolated(unsafe) static var backgroundTasksRegistered = false

    init() {
        Self.backgroundTasksRegistered = TrustSignalsSDK.registerBackgroundTasks(
            identifier: TestAppConfig.backgroundTaskIdentifier
        )
    }

    var body: some Scene {
        WindowGroup {
            if let launched {
                CollectionsView(settings: launched)
            } else {
                LaunchView(onLaunched: { launched = $0 })
            }
        }
    }
}

private struct LaunchView: View {
    let onLaunched: (LaunchSettings) -> Void

    @State private var collectionBaseURL: String = TestAppConfig.defaultCollectionBaseURL
    @State private var authBaseURL: String = TestAppConfig.defaultAuthBaseURL
    @State private var serviceId: String = TestAppConfig.defaultServiceId
    @State private var unitId: String = TestAppConfig.defaultUnitId
    @State private var sensorTag: String = "ios"
    @State private var reuseWindowSeconds: Int = 0
    @State private var error: String?

    var body: some View {
        NavigationStack {
            Form {
                Section("SDK Configuration") {
                    CaptionedTextField("Collection base URL", text: $collectionBaseURL, accessibilityIdentifier: "collection_base_url_input")
                        .textInputAutocapitalization(.never)
                        .autocorrectionDisabled()
                        .keyboardType(.URL)
                    CaptionedTextField("Auth server URL", text: $authBaseURL, accessibilityIdentifier: "launch_auth_base_url_input")
                        .textInputAutocapitalization(.never)
                        .autocorrectionDisabled()
                        .keyboardType(.URL)
                    CaptionedTextField("Service ID (UUID)", text: $serviceId, accessibilityIdentifier: "serviceid_input")
                        .textInputAutocapitalization(.never)
                        .autocorrectionDisabled()
                    CaptionedTextField("Unit ID", text: $unitId, accessibilityIdentifier: "unitid_input")
                        .textInputAutocapitalization(.never)
                        .autocorrectionDisabled()
                    CaptionedTextField("Sensor tag", text: $sensorTag)
                        .textInputAutocapitalization(.never)
                        .autocorrectionDisabled()
                }

                if let error {
                    Section("Error") {
                        Label(error, systemImage: "xmark.circle.fill")
                            .foregroundStyle(.red)
                            .font(.caption)
                    }
                }

                Section {
                    Button("Start TrustSignalsSDK") {
                        Task { await launch() }
                    }
                } footer: {
                    Text("Uploads go to the collection base URL + api/v1/collections. The auth server URL is where the OAuth2 client override fetches its token. Service ID and Unit ID are sent in every account's TSCredentials. Account IDs, cadences, the access token (pasted, or fetched from an OAuth2 client override that also replaces the Service ID) and the interaction are set on the next screen.")
                        .font(.caption)
                }

                Section {
                    Picker("Collection reuse window", selection: $reuseWindowSeconds) {
                        Text("Off — always fresh").tag(0)
                        Text("5 s").tag(5)
                        Text("30 s").tag(30)
                    }
                    .pickerStyle(.menu)
                    .accessibilityIdentifier("reuse_window_option")
                } header: {
                    Text("Advanced (optional)")
                } footer: {
                    Text("Scheduled uploads only. Off — the default — means every account always gets its own fresh collection, even when two are due in the same millisecond. A window lets accounts due within it share one sensor sweep, each still with its own collectionId. On-demand calls never reuse. Takes effect when the SDK starts.")
                        .font(.caption)
                }

                Section("About") {
                    HStack {
                        Text("SDK Version")
                        Spacer()
                        Text(TrustSignalsSDK.version)
                            .foregroundStyle(.secondary)
                            .monospaced()
                    }
                }
            }
            .navigationTitle("TrustSignals Test")
        }
    }

    @MainActor
    private func launch() async {
        error = nil
        guard let baseURL = Self.httpURL(collectionBaseURL) else {
            error = "Collection base URL must be an http(s) URL, e.g. https://collection.example.com/"
            return
        }
        // Only the optional client override uses it, so blank is fine.
        let trimmedAuthBaseURL = authBaseURL.trimmingCharacters(in: .whitespacesAndNewlines)
        guard trimmedAuthBaseURL.isEmpty || Self.httpURL(trimmedAuthBaseURL) != nil else {
            error = "Auth server URL must be an http(s) URL, e.g. https://auth.example.com/"
            return
        }
        let settings = LaunchSettings(
            collectionUrl: TestAppConfig.collectionUrl(baseURL: baseURL),
            authBaseURL: authBaseURL.trimmingCharacters(in: .whitespacesAndNewlines),
            serviceId: serviceId.trimmingCharacters(in: .whitespacesAndNewlines),
            unitId: unitId.trimmingCharacters(in: .whitespacesAndNewlines),
            sensorTag: sensorTag.trimmingCharacters(in: .whitespacesAndNewlines),
            reuseWindowSeconds: reuseWindowSeconds
        )
        await TrustSignalsSDK.initialize(settings.configuration)
        onLaunched(settings)
    }

    private static func httpURL(_ text: String) -> URL? {
        guard let url = URL(string: text.trimmingCharacters(in: .whitespacesAndNewlines)),
              let scheme = url.scheme?.lowercased(), scheme == "https" || scheme == "http",
              url.host != nil else { return nil }
        return url
    }
}
