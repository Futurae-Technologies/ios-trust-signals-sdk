import SwiftUI
import TrustSignals

struct CollectionDetailView: View {
    let collection: TSCollection

    var body: some View {
        List {
            Section("Header") {
                row("timestamp", "\(collection.timestamp)")
                row("date", Date(timeIntervalSince1970: TimeInterval(collection.timestamp))
                    .formatted(date: .abbreviated, time: .standard))
                row("tag", collection.tag)
                row("collectionId", collection.collectionId.uuidString)
            }

            Section("observation.wifiScan") {
                if let wifi = collection.observation.wifiScan {
                    permissionRow(wifi.permission)
                    if wifi.scanResults.isEmpty {
                        empty("no scan results — iOS does not expose Wi-Fi scan to apps")
                    } else {
                        ForEach(wifi.scanResults) { device(device: $0) }
                    }
                } else { empty("not collected") }
            }

            Section("observation.bleScan") {
                if let ble = collection.observation.bleScan {
                    permissionRow(ble.permission)
                    if ble.scanResults.isEmpty {
                        empty("no peripherals discovered")
                    } else {
                        ForEach(ble.scanResults) { device(device: $0) }
                    }
                } else { empty("not collected") }
            }

            Section("observation.locationCollection") {
                if let loc = collection.observation.locationCollection {
                    row("lat", String(format: "%.6f", loc.lat))
                    row("lon", String(format: "%.6f", loc.lon))
                    row("timestamp", "\(loc.timestamp)")
                } else { empty("not collected (permission denied or not yet granted)") }
            }

            Section("observation.wifiNetwork") {
                if let net = collection.observation.wifiNetwork {
                    row("name", net.name ?? "—")
                    row("timestamp", "\(net.timestamp)")
                    if !net.connectedDevices.isEmpty {
                        ForEach(net.connectedDevices) { device(device: $0) }
                    }
                } else { empty("not joined to a Wi-Fi network or no entitlement") }
            }

            Section("observation.blePeripherals") {
                if let peri = collection.observation.blePeripherals {
                    permissionRow(peri.permission)
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

            Section("Raw JSON") {
                Text(prettyJSON)
                    .font(.system(.caption, design: .monospaced))
                    .textSelection(.enabled)
            }
        }
        .navigationTitle(Date(timeIntervalSince1970: TimeInterval(collection.timestamp))
            .formatted(date: .omitted, time: .standard))
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
            Text(granted ? "permission: true" : "permission: false")
                .font(.caption)
                .foregroundStyle(granted ? .green : .red)
        }
    }

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
}
