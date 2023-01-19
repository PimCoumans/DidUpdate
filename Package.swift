// swift-tools-version: 5.4
// The swift-tools-version declares the minimum version of Swift required to build this package.

import PackageDescription

let package = Package(
    name: "DidUpdate",
    products: [
        .library(
            name: "DidUpdate",
            targets: ["DidUpdate"]),
    ],
    targets: [
        .target(
            name: "DidUpdate"),
        .testTarget(
            name: "DidUpdateTests",
            dependencies: ["DidUpdate"]),
    ]
)
