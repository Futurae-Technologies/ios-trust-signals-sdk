import SwiftUI
import TrustSignals

enum TestAppConfig {
    static let serverURL = URL(string: "https://tscollection.public.futurae.dev/")!
    static let backgroundTaskIdentifier = "com.futurae.trustsignals.refresh"
}

@main
struct TrustSignalsTestApp: App {
    @State private var sdkStarted: Bool = false

    var body: some Scene {
        WindowGroup {
            if sdkStarted {
                CollectionsView()
            } else {
                LaunchView(onLaunched: { sdkStarted = true })
            }
        }
    }
}

private struct LaunchView: View {
    let onLaunched: () -> Void

    @State private var appID: String = ""
    @State private var tag: String = "ios"
    @State private var error: String?

    var body: some View {
        NavigationStack {
            Form {
                Section("SDK Configuration") {
                    TextField("App ID", text: $appID)
                        .textInputAutocapitalization(.never)
                        .autocorrectionDisabled()
                    TextField("Tag", text: $tag)
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
                    Text("Account ID and access token are set on the next screen.")
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
        let trimmedAppID = appID.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmedAppID.isEmpty else {
            error = "App ID is required."
            return
        }
        await TrustSignalsSDK.initialize(
            TSConfiguration(
                serverURL: TestAppConfig.serverURL,
                appID: trimmedAppID,
                tag: tag.trimmingCharacters(in: .whitespacesAndNewlines),
                backgroundTaskIdentifier: TestAppConfig.backgroundTaskIdentifier
            )
        )
        onLaunched()
    }
}
