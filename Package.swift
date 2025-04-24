// swift-tools-version: 6.1
// The swift-tools-version declares the minimum version of Swift required to build this package.

import PackageDescription

let package = Package(

  name: "macos-toolchain-finder",
  platforms: [
    .macOS(.v15)
  ],

  products: [
    .executable(
      name: "macos-toolchain-finder",
    targets: ["macos-toolchain-finder"]),
  ],

  dependencies: [
    .package(url: "https://github.com/apple/swift-argument-parser", from: "1.5.0")],

  targets: [
    .executableTarget(
      name: "macos-toolchain-finder",
      dependencies: [
        .product(name: "ArgumentParser", package: "swift-argument-parser")]),
  ]
)
