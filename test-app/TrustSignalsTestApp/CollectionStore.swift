import Foundation
import TrustSignals
import SwiftUI

@MainActor
final class CollectionStore: ObservableObject {
    @Published private(set) var collections: [TSCollection] = []
    @Published private(set) var isBusy: Bool = false
    @Published var lastError: String?
    @Published var scheduleSeconds: Int = 0
    @Published var accessToken: String = ""
    @Published var accountID: String = ""

    private var observerTask: Task<Void, Never>?

    func startObserving() async {
        observerTask?.cancel()
        observerTask = Task { [weak self] in
            let stream = await TrustSignalsSDK.collections
            for await collection in stream {
                await MainActor.run { self?.append(collection) }
            }
        }

        await TrustSignalsSDK.registerErrorHandler { [weak self] accountID, error in
            Task { @MainActor in
                if error is TSAuthenticationError {
                    self?.lastError = "Scheduled upload for \(accountID) — token rejected, refresh and re-schedule"
                } else {
                    self?.lastError = "Scheduled upload for \(accountID) failed: \(error.localizedDescription)"
                }
            }
        }
    }

    func collectNow() async {
        isBusy = true
        lastError = nil
        do {
            _ = try await TrustSignalsSDK.collect()
        } catch {
            lastError = error.localizedDescription
        }
        isBusy = false
    }

    func collectAndUpload() async {
        isBusy = true
        lastError = nil
        do {
            _ = try await TrustSignalsSDK.collectAndUpload(
                accessToken: accessToken,
                accountID: accountID
            )
        } catch {
            lastError = error.localizedDescription
        }
        isBusy = false
    }

    func applySchedule(seconds: Int) async {
        if seconds == 0 {
            await TrustSignalsSDK.scheduleCollections(
                interval: .zero,
                accessToken: accessToken,
                accountID: accountID
            )
        } else {
            await TrustSignalsSDK.scheduleCollections(
                interval: .seconds(Double(seconds)),
                accessToken: accessToken,
                accountID: accountID
            )
        }
    }

    private func append(_ collection: TSCollection) {
        collections.insert(collection, at: 0)
    }

    deinit {
        observerTask?.cancel()
    }
}
