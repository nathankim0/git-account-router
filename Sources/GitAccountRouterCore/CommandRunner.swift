import Foundation

public struct CommandResult: Sendable {
  public let exitCode: Int32
  public let standardOutput: String
  public let standardError: String

  public var combinedOutput: String {
    [standardOutput, standardError]
      .filter { !$0.isEmpty }
      .joined(separator: "\n")
  }

  public init(exitCode: Int32, standardOutput: String, standardError: String) {
    self.exitCode = exitCode
    self.standardOutput = standardOutput
    self.standardError = standardError
  }
}

public protocol CommandRunning: Sendable {
  func run(
    executable: String,
    arguments: [String],
    currentDirectory: String?,
    environment: [String: String]?
  ) async throws -> CommandResult
}

extension CommandRunning {
  public func run(
    executable: String,
    arguments: [String],
    currentDirectory: String? = nil
  ) async throws -> CommandResult {
    try await run(
      executable: executable,
      arguments: arguments,
      currentDirectory: currentDirectory,
      environment: nil
    )
  }
}

public actor ProcessCommandRunner: CommandRunning {
  public init() {}

  public func run(
    executable: String,
    arguments: [String],
    currentDirectory: String?,
    environment: [String: String]?
  ) async throws -> CommandResult {
    let process = Process()
    let stdoutPipe = Pipe()
    let stderrPipe = Pipe()

    process.executableURL = URL(fileURLWithPath: executable)
    process.arguments = arguments
    process.standardOutput = stdoutPipe
    process.standardError = stderrPipe

    if let currentDirectory {
      process.currentDirectoryURL = URL(fileURLWithPath: currentDirectory)
    }
    if let environment {
      process.environment = ProcessInfo.processInfo.environment.merging(environment) { _, new in new
      }
    }

    try process.run()
    process.waitUntilExit()

    let stdout = stdoutPipe.fileHandleForReading.readDataToEndOfFile()
    let stderr = stderrPipe.fileHandleForReading.readDataToEndOfFile()

    return CommandResult(
      exitCode: process.terminationStatus,
      standardOutput: String(decoding: stdout, as: UTF8.self).trimmingCharacters(
        in: .whitespacesAndNewlines),
      standardError: String(decoding: stderr, as: UTF8.self).trimmingCharacters(
        in: .whitespacesAndNewlines)
    )
  }
}

public enum ToolLocator {
  public static func find(_ name: String, fileManager: FileManager = .default) -> String? {
    let environmentPaths =
      ProcessInfo.processInfo.environment["PATH"]?
      .split(separator: ":")
      .map(String.init) ?? []
    let commonPaths = [
      "/opt/homebrew/bin",
      "/usr/local/bin",
      "/usr/bin",
      "/bin",
    ]

    for directory in environmentPaths + commonPaths {
      let candidate = URL(fileURLWithPath: directory).appendingPathComponent(name).path
      if fileManager.isExecutableFile(atPath: candidate) {
        return candidate
      }
    }
    return nil
  }
}
