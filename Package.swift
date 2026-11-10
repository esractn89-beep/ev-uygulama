// swift-tools-version:5.9
import PackageDescription

// Uygulamanın platformdan bağımsız çekirdeği (modeller, puanlama, skor tablosu).
// Linux'ta da derlenip test edilebilir: `swift test`
let package = Package(
    name: "EvdeAdaletCore",
    platforms: [.iOS(.v17), .macOS(.v14)],
    products: [
        .library(name: "EvdeAdaletCore", targets: ["EvdeAdaletCore"])
    ],
    targets: [
        .target(name: "EvdeAdaletCore"),
        .testTarget(name: "EvdeAdaletCoreTests", dependencies: ["EvdeAdaletCore"])
    ]
)
