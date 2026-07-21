// swift-tools-version: 5.9
import PackageDescription

let package = Package(
    name: "Biquge",
    platforms: [
        .iOS(.v16),
    ],
    dependencies: [
        // HTML parser，对标 Java Jsoup，用于 CSS 选择器求值
        .package(url: "https://github.com/scinfu/SwiftSoup.git", from: "2.7.0"),
    ],
    targets: [
        .target(
            name: "Biquge",
            dependencies: ["SwiftSoup"],
            resources: [.process("Resources")]
        ),
    ]
)