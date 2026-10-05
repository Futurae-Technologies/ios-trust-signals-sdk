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
            url: "https://github.com/Futurae-Technologies/ios-trust-signals-sdk/releases/download/v0.1.0-alpha/TrustSignals-0.1.0-alpha.xcframework.zip",
            checksum: "10925e81e50b9f10dab276a89a2440f31a06e1c1656a067df6dcde06c666781d"
        )
    ]
)
