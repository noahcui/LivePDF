// swift-tools-version: 5.9
import PackageDescription

let package = Package(
    name: "LivePDF",
    platforms: [.macOS(.v14)],
    products: [
        .executable(name: "LivePDF", targets: ["LivePDF"]),
        .library(name: "LivePDFCore", targets: ["LivePDFCore"])
    ],
    targets: [
        .target(name: "LivePDFCore"),
        .executableTarget(name: "LivePDF", dependencies: ["LivePDFCore"]),
        .testTarget(name: "LivePDFCoreTests", dependencies: ["LivePDFCore"])
    ]
)
