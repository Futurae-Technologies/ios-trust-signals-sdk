import SwiftUI
import TrustSignals

struct CollectionDetailView: View {
    let collection: TSCollection
    var accountId: String = ""
    /// The identity fields as this session has them, so the preview shows the body that
    /// would actually go out.
    var serviceId: String = ""
    var unitId: String = ""
    var interactionId: String = ""
    var verificationStatus: TSVerificationStatus = .unverified

    @Environment(\.dismiss) private var dismiss

    var body: some View {
        List {
            Section("Header") {
                row("observationTime", collection.observationTime.formatted(Self.rfc3339))
                row("date", collection.observationTime
                    .formatted(date: .abbreviated, time: .standard))
                row("sensorTag", collection.sensorTag)
                row("collectionId", collection.collectionId.uuidString)
            }

            Section("observation.wifiScan") {
                if let wifi = collection.observation.wifiScan {
                    permissionRow(wifi.permissionGranted)
                    if wifi.scanResults.isEmpty {
                        empty("no scan results — iOS does not expose Wi-Fi scan to apps")
                    } else {
                        ForEach(wifi.scanResults) { device(device: $0) }
                    }
                } else { empty("not collected") }
            }

            Section("observation.bleScan") {
                if let ble = collection.observation.bleScan {
                    permissionRow(ble.permissionGranted)
                    if ble.scanResults.isEmpty {
                        empty("no peripherals discovered")
                    } else {
                        ForEach(ble.scanResults) { device(device: $0) }
                    }
                } else { empty("not collected") }
            }

            Section("observation.location") {
                if let loc = collection.observation.location {
                    row("lat", String(format: "%.6f", loc.lat))
                    row("lon", String(format: "%.6f", loc.lon))
                    row("observationTime", loc.observationTime.formatted(Self.rfc3339))
                } else { empty("not collected (permission denied or not yet granted)") }
            }

            Section("observation.wifiNetwork") {
                if let net = collection.observation.wifiNetwork {
                    row("name", net.name ?? "—")
                    row("observationTime", net.observationTime.formatted(Self.rfc3339))
                    if !net.connectedDevices.isEmpty {
                        ForEach(net.connectedDevices) { device(device: $0) }
                    }
                } else { empty("not joined to a Wi-Fi network or no entitlement") }
            }

            Section("observation.blePeripherals") {
                if let peri = collection.observation.blePeripherals {
                    permissionRow(peri.permissionGranted)
                    if peri.connectedBLEs.isEmpty {
                        empty("no connected peripherals")
                    } else {
                        ForEach(peri.connectedBLEs) { device(device: $0) }
                    }
                } else { empty("not collected") }
            }

            Section("observation.nearbyDevices (\(collection.observation.nearbyDevices.count))") {
                if collection.observation.nearbyDevices.isEmpty {
                    empty("no Bonjour services discovered")
                } else {
                    ForEach(collection.observation.nearbyDevices) { device(device: $0) }
                }
            }

            Section("observation network/timezone") {
                row("ip", collection.observation.ip ?? "—")
                row("timezone", collection.observation.timezone)
                row("timezone (localized)", localizedTimezone)
            }

            Section("observation.activeCall") {
                if let active = collection.observation.activeCall {
                    row("in-flight call", active ? "true" : "false")
                } else {
                    empty("not collected")
                }
            }

            Section("deviceInfoSignals — Device") {
                row("modelIdentifier", collection.deviceInfoSignals.deviceModelIdentifier ?? "—")
                row("deviceName", collection.deviceInfoSignals.deviceName ?? "—")
                row("screenResolution", collection.deviceInfoSignals.screenResolution ?? "—")
                row("screenScale", collection.deviceInfoSignals.screenScale.map { String(format: "%.1f", $0) } ?? "—")
                row("screenBrightness", collection.deviceInfoSignals.screenBrightness.map { String(format: "%.2f", $0) } ?? "—")
                row("thermalState", collection.deviceInfoSignals.thermalState ?? "—")
                row("proximityState", collection.deviceInfoSignals.proximityState.map(String.init(describing:)) ?? "—")
            }

            Section("deviceInfoSignals — OS") {
                row("systemName", collection.deviceInfoSignals.systemName ?? "—")
                row("systemVersion", collection.deviceInfoSignals.systemVersion ?? "—")
                row("systemUptime", collection.deviceInfoSignals.systemUptime.map { String(format: "%.1f s", $0) } ?? "—")
                row("lowPowerMode", collection.deviceInfoSignals.lowPowerMode.map(String.init(describing:)) ?? "—")
            }

            Section("deviceInfoSignals — Locale + Identifier") {
                row("preferredLanguage", collection.deviceInfoSignals.preferredLanguage ?? "—")
                row("regionCode", collection.deviceInfoSignals.regionCode ?? "—")
                row("idfv", collection.deviceInfoSignals.idfv ?? "—")
            }

            Section("deviceInfoSignals — App + Battery + Security") {
                row("appVersion", collection.deviceInfoSignals.appVersion ?? "—")
                row("appBuildNumber", collection.deviceInfoSignals.appBuildNumber ?? "—")
                row("batteryLevel", collection.deviceInfoSignals.batteryLevel.map { String(format: "%.0f %%", $0 * 100) } ?? "—")
                row("batteryState", collection.deviceInfoSignals.batteryState ?? "—")
                row("debuggerAttached", collection.deviceInfoSignals.debuggerAttached.map(String.init(describing:)) ?? "—")
            }

            Section {
                Text(wireJSON)
                    .font(.system(.caption, design: .monospaced))
                    .textSelection(.enabled)
            } header: {
                Text("Wire JSON — POST /api/v1/collections")
            } footer: {
                Text("The exact envelope shape uploaded to the backend: a flattened `observation` wrapped with accountId / sdkVersionId plus the four identity fields. Values come from this session.")
            }

            Section("Raw JSON with collected data from the device") {
                Button {
                    UIPasteboard.general.string = prettyJSON
                } label: {
                    Label("Copy", systemImage: "doc.on.doc")
                }
                .accessibilityIdentifier("copy_json")
                Text(prettyJSON)
                    .font(.system(.caption, design: .monospaced))
                    .textSelection(.enabled)
                    .accessibilityIdentifier("raw_json_text")
            }
        }
        .navigationTitle(collection.observationTime
            .formatted(date: .omitted, time: .standard))
        .navigationBarBackButtonHidden(true)
        .toolbar {
            ToolbarItem(placement: .navigationBarLeading) {
                Button {
                    dismiss()
                } label: {
                    Image(systemName: "chevron.left")
                }
                .accessibilityIdentifier("collection_detail_back")
            }
        }
    }

    @ViewBuilder
    private func row(_ label: String, _ value: String) -> some View {
        HStack {
            Text(label).font(.caption).foregroundStyle(.secondary)
            Spacer()
            Text(value).font(.caption).monospaced().textSelection(.enabled)
        }
    }

    @ViewBuilder
    private func device(device: TSDevice) -> some View {
        VStack(alignment: .leading) {
            Text(device.name ?? "—").font(.caption)
            Text(device.address).font(.caption2).monospaced().foregroundStyle(.secondary)
            Text(device.observationTime.formatted(Self.rfc3339)).font(.caption2).monospaced().foregroundStyle(.secondary)
        }
    }

    @ViewBuilder
    private func empty(_ text: String) -> some View {
        Text(text).font(.caption).foregroundStyle(.secondary).italic()
    }

    @ViewBuilder
    private func permissionRow(_ granted: Bool) -> some View {
        HStack {
            Image(systemName: granted ? "checkmark.shield.fill" : "lock.shield.fill")
                .foregroundStyle(granted ? .green : .red)
            Text(granted ? "permissionGranted: true" : "permissionGranted: false")
                .font(.caption)
                .foregroundStyle(granted ? .green : .red)
        }
    }

    /// Same format the SDK sends, so the header matches the wire preview.
    static let rfc3339 = Date.ISO8601FormatStyle(includingFractionalSeconds: true)

    private var localizedTimezone: String {
        TimeZone(identifier: collection.observation.timezone)?
            .localizedName(for: .standard, locale: .current) ?? "—"
    }

    private var prettyJSON: String {
        let encoder = JSONEncoder()
        encoder.outputFormatting = [.sortedKeys, .prettyPrinted, .withoutEscapingSlashes]
        guard let data = try? encoder.encode(collection),
              let str = String(data: data, encoding: .utf8) else {
            return "<encoding error>"
        }
        return str
    }

    private var wireJSON: String {
        WireRequestPreview(
            collection: collection,
            accountId: accountId,
            sdkVersionId: TrustSignalsSDK.version,
            serviceId: serviceId,
            unitId: unitId,
            interactionId: interactionId,
            verificationStatus: verificationStatus
        ).json()
    }
}

private struct WireRequestPreview: Encodable {
    let accountId: String
    let serviceId: String
    let unitId: String
    let interactionId: String
    let verificationStatus: TSVerificationStatus
    let sdkVersionId: String
    let observationTime: String
    let sensorTag: String
    let timedOut: Bool
    let observation: WireObservationPreview

    init(
        collection: TSCollection,
        accountId: String,
        sdkVersionId: String,
        serviceId: String,
        unitId: String,
        interactionId: String,
        verificationStatus: TSVerificationStatus
    ) {
        self.accountId = accountId
        self.serviceId = serviceId
        self.unitId = unitId
        self.interactionId = interactionId
        self.verificationStatus = verificationStatus
        self.sdkVersionId = sdkVersionId
        self.observationTime = collection.observationTime.formatted(CollectionDetailView.rfc3339)
        self.sensorTag = collection.sensorTag
        self.timedOut = collection.timedOut
        self.observation = WireObservationPreview(collection.observation, deviceInfoSignals: collection.deviceInfoSignals)
    }

    func json(prettyPrinted: Bool = true) -> String {
        let encoder = JSONEncoder()
        var formatting: JSONEncoder.OutputFormatting = [.sortedKeys, .withoutEscapingSlashes]
        if prettyPrinted { formatting.insert(.prettyPrinted) }
        encoder.outputFormatting = formatting
        guard let data = try? encoder.encode(self),
              let str = String(data: data, encoding: .utf8) else {
            return "<encoding error>"
        }
        return str
    }
}

private struct WireObservationPreview: Encodable {
    let bleScan: TSBleScan?
    let blePeripherals: TSBlePeripherals?
    let nearbyDevices: [TSDevice]
    let location: TSLocation?
    let wifiNetwork: TSWifiNetwork?
    let ip: String?
    let timezone: String
    let activeCall: Bool
    let deviceInfoSignals: TSDeviceInfoSignals

    init(_ observation: TSObservation, deviceInfoSignals: TSDeviceInfoSignals) {
        self.bleScan = observation.bleScan
        self.blePeripherals = observation.blePeripherals
        self.nearbyDevices = observation.nearbyDevices
        self.location = observation.location
        self.wifiNetwork = observation.wifiNetwork
        self.ip = observation.ip
        self.timezone = observation.timezone
        self.activeCall = observation.activeCall ?? false
        self.deviceInfoSignals = deviceInfoSignals
    }
}
