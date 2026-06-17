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
            url: "https://github.com/Futurae-Technologies/ios-trust-signals-sdk/releases/download/v0.0.1-alpha/TrustSignals-0.0.1-alpha.xcframework.zip",
            checksum: "4526044716e6296d52a237dc67b896dca6d40c4ff4daf0ad615712647353a8cb"
        )
    ]
)
