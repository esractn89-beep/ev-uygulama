// swift-tools-version:5.9
import PackageDescription

// Uygulamanın platformdan bağımsız çekirdeği (modeller, puanlama, skor tablosu).
// Linux'ta da derlenip test edilebilir: `swift test`
let package = Package(
    name: "BebekPuanCore",
    platforms: [.iOS(.v17), .macOS(.v14)],
    products: [
        .library(name: "BebekPuanCore", targets: ["BebekPuanCore"])
    ],
    targets: [
        .target(name: "BebekPuanCore"),
        .testTarget(name: "BebekPuanCoreTests", dependencies: ["BebekPuanCore"])
    ]
)
