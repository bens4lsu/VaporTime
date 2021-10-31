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
        .package(name: "SwiftSMTP", url: "https://github.com/IBM-Swift/Swift-SMTP.git", .upToNextMinor(from: "5.1.0")),
        // pin the logger in IBM-Swift/LoggerAPI to an older version
        // see https://forums.swift.org/t/logging-module-name-clash-in-vapor-3/25466
        //.package(url: "https://github.com/IBM-Swift/LoggerAPI.git", .upToNextMinor(from: "1.8.0")),

    ],
    
    targets: [
        .target(name: "App",
                dependencies: [
                    .product(name: "Vapor", package: "vapor"),
                    .product(name: "SwiftSMTP", package: "SwiftSMTP"),
                    .product(name: "Leaf", package: "leaf"),
                    .product(name: "Fluent", package: "fluent"),
                    .product(name: "FluentMySQLDriver", package:"fluent-mysql-driver"),
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

