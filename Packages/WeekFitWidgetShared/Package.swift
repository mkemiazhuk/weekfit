// swift-tools-version: 5.9
import PackageDescription

let package = Package(
    name: "WeekFitWidgetShared",
    platforms: [.iOS(.v17), .macOS(.v14)],
    products: [
        .library(name: "WeekFitWidgetShared", targets: ["WeekFitWidgetShared"]),
    ],
    targets: [
        .target(name: "WeekFitWidgetShared"),
        .testTarget(
            name: "WeekFitWidgetSharedTests",
            dependencies: ["WeekFitWidgetShared"]
        ),
    ]
)
