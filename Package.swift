// swift-tools-version: 6.0

import PackageDescription

let package = Package(
  name: "GitAccountRouter",
  platforms: [.macOS(.v14)],
  products: [
    .library(name: "GitAccountRouterCore", targets: ["GitAccountRouterCore"]),
    .executable(name: "GitAccountRouter", targets: ["GitAccountRouter"]),
    .executable(name: "git-account-status", targets: ["GitAccountStatus"]),
    .executable(name: "GitAccountRouterTests", targets: ["GitAccountRouterCoreTests"]),
  ],
  targets: [
    .target(name: "GitAccountRouterCore"),
    .executableTarget(
      name: "GitAccountRouter",
      dependencies: ["GitAccountRouterCore"],
      resources: [.process("Resources")]
    ),
    .executableTarget(
      name: "GitAccountStatus",
      dependencies: ["GitAccountRouterCore"]
    ),
    .executableTarget(
      name: "GitAccountRouterCoreTests",
      dependencies: ["GitAccountRouterCore"],
      path: "Tests/GitAccountRouterCoreTests"
    ),
  ]
)
