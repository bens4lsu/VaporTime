// swift-tools-version:5.5
import PackageDescription

let package = Package(
    name: "VaporTime",
    platforms: [
        .macOS(.v12),
    ],
    dependencies: [
        // 💧 A server-side Swift web framework.

        .package(url: "https://github.com/vapor/vapor.git", from: "4.0.0"),
        .package(url: "https://github.com/vapor/fluent.git", from: "4.0.0"),
        .package(url: "https://github.com/vapor/fluent-mysql-driver.git", from: "4.0.0"),
        .package(url: "https://github.com/vapor/leaf.git", from: "4.0.0"),
        .package(url: "https://github.com/Joannis/SMTPKitten.git", from: "0.1.6")
    ],
    
    targets: [
        .target(name: "App",
                dependencies: [
                    .product(name: "Vapor", package: "vapor"),
                    .product(name: "Leaf", package: "leaf"),
                    .product(name: "Fluent", package: "fluent"),
                    .product(name: "FluentMySQLDriver", package:"fluent-mysql-driver"),
                    .product(name: "SMTPKitten", package: "SMTPKitten")
                ],
                swiftSettings: [
                    // Enable better optimizations when building in Release configuration. Despite the use of
                    // the `.unsafeFlags` construct required by SwiftPM, this flag is recommended for Release
                    // builds. See <https://github.com/swift-server/guides#building-for-production> for details.
                    .unsafeFlags(["-cross-module-optimization"], .when(configuration: .release))
                ]),
        .executableTarget(name: "Run", dependencies: [.target(name: "App")]),
        .testTarget(name: "AppTests", dependencies: [
            .target(name: "App"),
            .product(name: "XCTVapor", package: "vapor")])
    ]
)

