// swift-tools-version: 6.2

import PackageDescription

let package = Package(
    name: "markdown-toc",
    platforms: [.macOS(.v13)],
    products: [
        .executable(name: "markdown-toc", targets: ["markdown-toc"]),
        .library(name: "MarkdownToCLib", targets: ["MarkdownToCLib"]),
    ],
    dependencies: [
        .package(url: "https://github.com/swiftlang/swift-markdown.git", revision: "55d66d9a9e8d4fd3f48d111b0d437e82fe451903"),
        .package(url: "https://github.com/apple/swift-argument-parser.git", from: "1.5.0"),
    ],
    targets: [
        .target(
            name: "MarkdownToCLib",
            dependencies: [
                .product(name: "Markdown", package: "swift-markdown"),
            ]
        ),
        .executableTarget(
            name: "markdown-toc",
            dependencies: [
                "MarkdownToCLib",
                .product(name: "ArgumentParser", package: "swift-argument-parser"),
            ]
        ),
        .testTarget(
            name: "MarkdownToCLibTests",
            dependencies: ["MarkdownToCLib"]
        ),
    ]
)
