// swift-tools-version: 5.9
import PackageDescription

let package = Package(
    name: "WeekFitCoachCore",
    platforms: [.iOS(.v17)],
    products: [
        .library(name: "WeekFitCoachCore", targets: ["WeekFitCoachCore"]),
    ],
    targets: [
        .target(name: "WeekFitCoachCore"),
        .testTarget(
            name: "WeekFitCoachCoreTests",
            dependencies: ["WeekFitCoachCore"]
        ),
    ]
)
