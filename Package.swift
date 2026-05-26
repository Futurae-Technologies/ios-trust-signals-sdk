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
            checksum: "84d2211a8bc023ac5c1c53e7173c192c83790d85261fb443f66d3663a43e29cd"
        )
    ]
)
