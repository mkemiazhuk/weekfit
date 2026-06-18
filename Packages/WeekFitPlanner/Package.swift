// swift-tools-version: 5.9
import PackageDescription

let package = Package(
    name: "WeekFitPlanner",
    platforms: [.iOS(.v17)],
    products: [
        .library(name: "WeekFitPlanner", targets: ["WeekFitPlanner"]),
    ],
    targets: [
        .target(name: "WeekFitPlanner"),
        .testTarget(
            name: "WeekFitPlannerTests",
            dependencies: ["WeekFitPlanner"]
        ),
    ]
)
