// swift-tools-version: 5.9
import PackageDescription

let package = Package(
    name: "TrustSignals",
    platforms: [
        .iOS(.v16)
    ],
    products: [
        .library(name: "TrustSignals", targets: ["TrustSignals"])
    ],
    targets: [
        .binaryTarget(
            name: "TrustSignals",
            url: "https://github.com/Futurae-Technologies/ios-trust-signals-sdk/releases/download/v1.0.0/TrustSignals-1.0.0.xcframework.zip",
            checksum: "2c13715612300986123c071d609914c306c0af2df09a6a713c145d97255a703b"
        )
    ]
)
