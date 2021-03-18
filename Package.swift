// swift-tools-version:5.3
import PackageDescription

let package = Package(
    name: "VaporTime",
    platforms: [
        .macOS(.v10_15),
    ],
    dependencies: [
        // 💧 A server-side Swift web framework.
        .package(url: "https://github.com/vapor/vapor.git", from: "4.0.0-rc"),
        .package(url: "https://github.com/vapor/fluent.git", from: "4.0.0-rc"),
        .package(url: "https://github.com/vapor/fluent-mysql-driver.git", from: "4.0.0-rc"),
        .package(url: "https://github.com/vapor/leaf.git", .upToNextMinor(from: "4.0.0")),
        .package(url: "https://github.com/IBM-Swift/Swift-SMTP.git", .upToNextMinor(from: "5.1.0")),
        // pin the logger in IBM-Swift/LoggerAPI to an older version
        // see https://forums.swift.org/t/logging-module-name-clash-in-vapor-3/25466
        //.package(url: "https://github.com/IBM-Swift/LoggerAPI.git", .upToNextMinor(from: "1.8.0")),

    ],
    targets: [
        .target(name: "App", dependencies: [
            .product(name: "Fluent", package: "fluent"),
            .product(name: "FluentMySQLDriver", package: "fluent-mysql-driver"),
            .product(name: "Vapor", package: "vapor"),
            .product(name: "Swift0-SMTP", package: "Swift-SMTP")
        ]),
        .target(name: "Run", dependencies: ["App"]),
        .testTarget(name: "AppTests", dependencies: [
            .target(name: "App"),
            .product(name: "XCTVapor", package: "vapor")])
    ]
)

