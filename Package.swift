// swift-tools-version:4.0
import PackageDescription

let package = Package(
    name: "VaporTime",
    products: [
        .library(name: "VaporTime", targets: ["App"]),
    ],
    dependencies: [
        // 💧 A server-side Swift web framework.
        .package(url: "https://github.com/vapor/vapor.git", from: "3.3.0"),
        .package(url: "https://github.com/vapor/fluent-mysql.git", .upToNextMinor(from: "3.0.0")),
        .package(url: "https://github.com/vapor/leaf.git", .upToNextMinor(from: "3.0.0")),
        .package(url: "https://github.com/IBM-Swift/Swift-SMTP.git", .upToNextMinor(from: "5.1.0")),
        // pin the logger in IBM-Swift/LoggerAPI to an older version
        // see https://forums.swift.org/t/logging-module-name-clash-in-vapor-3/25466
        .package(url: "https://github.com/IBM-Swift/LoggerAPI.git", .upToNextMinor(from: "1.8.0")),

    ],
    targets: [
        .target(name: "App", dependencies: ["Vapor", "Leaf", "FluentMySQL", "SwiftSMTP"]),
        .target(name: "Run", dependencies: ["App"]),
        .testTarget(name: "AppTests", dependencies: ["App"])
    ]
)

