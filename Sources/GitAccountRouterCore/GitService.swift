import Foundation

public struct GitService: Sendable {
  private let runner: any CommandRunning
  public let executable: String

  public init(runner: any CommandRunning, executable: String? = nil) throws {
    guard let resolved = executable ?? ToolLocator.find("git") else {
      throw RouterError.toolMissing("Git")
    }
    self.runner = runner
    self.executable = resolved
  }

  public func isRepository(at path: String) async -> Bool {
    guard let result = try? await run(["rev-parse", "--is-inside-work-tree"], at: path) else {
      return false
    }
    return result.exitCode == 0 && result.standardOutput == "true"
  }

  public func initializeRepository(at path: String) async throws {
    let result = try await runner.run(
      executable: executable,
      arguments: ["init", "-b", "main"],
      currentDirectory: path
    )
    guard result.exitCode == 0 else {
      throw RouterError.commandFailed(command: "git init", output: result.combinedOutput)
    }
  }

  public func repositoryRoot(at path: String) async throws -> String {
    let result = try await run(["rev-parse", "--show-toplevel"], at: path)
    guard result.exitCode == 0 else { throw RouterError.notGitRepository(path) }
    return result.standardOutput
  }

  public func branch(at path: String) async -> String? {
    let result = try? await run(["branch", "--show-current"], at: path)
    return result?.exitCode == 0 ? result?.standardOutput.nilIfEmpty : nil
  }

  public func originURL(at path: String) async -> String? {
    let result = try? await run(["remote", "get-url", "origin"], at: path)
    return result?.exitCode == 0 ? result?.standardOutput.nilIfEmpty : nil
  }

  public func setOriginURL(_ url: String, at path: String) async throws {
    let hasOrigin = await originURL(at: path) != nil
    let arguments =
      hasOrigin
      ? ["remote", "set-url", "origin", url]
      : ["remote", "add", "origin", url]
    let result = try await run(arguments, at: path)
    guard result.exitCode == 0 else {
      throw RouterError.commandFailed(command: "git remote", output: result.combinedOutput)
    }
  }

  public func localConfig(_ key: String, at path: String) async -> String? {
    let result = try? await run(["config", "--local", "--get", key], at: path)
    return result?.exitCode == 0 ? result?.standardOutput.nilIfEmpty : nil
  }

  public func setLocalConfig(_ key: String, value: String, at path: String) async throws {
    let result = try await run(["config", "--local", key, value], at: path)
    guard result.exitCode == 0 else {
      throw RouterError.commandFailed(command: "git config", output: result.combinedOutput)
    }
  }

  public func removeLocalConfig(_ key: String, at path: String) async {
    _ = try? await run(["config", "--local", "--unset-all", key], at: path)
  }

  public func currentAccount(at path: String, activeHTTPSAccount: String?) async -> String? {
    if let managed = await localConfig("git-account-router.account", at: path) {
      return managed
    }
    guard let remoteValue = await originURL(at: path),
      let remote = RemoteURLParser.parse(remoteValue)
    else {
      return nil
    }
    if remote.transport == .https {
      return activeHTTPSAccount
    }

    let result = try? await runner.run(
      executable: ToolLocator.find("ssh") ?? "/usr/bin/ssh",
      arguments: ["-o", "BatchMode=yes", "-o", "ConnectTimeout=5", "-T", "git@\(remote.host)"]
    )
    return result.flatMap { GitHubIdentityParser.account(fromSSHOutput: $0.combinedOutput) }
  }

  public func snapshot(
    for project: RegisteredProject,
    activeHTTPSAccount: String?
  ) async -> ProjectSnapshot {
    guard await isRepository(at: project.path) else {
      return ProjectSnapshot(projectID: project.id, isRepository: false)
    }
    let branchValue = await branch(at: project.path)
    let remoteValue = await originURL(at: project.path)
    let accountValue = await currentAccount(
      at: project.path, activeHTTPSAccount: activeHTTPSAccount)
    let managed = await localConfig("git-account-router.account", at: project.path) != nil
    return ProjectSnapshot(
      projectID: project.id,
      isRepository: true,
      branch: branchValue,
      remoteURL: remoteValue,
      connectedAccount: accountValue,
      routingManaged: managed
    )
  }

  private func run(_ arguments: [String], at path: String) async throws -> CommandResult {
    try await runner.run(executable: executable, arguments: ["-C", path] + arguments)
  }
}

extension String {
  fileprivate var nilIfEmpty: String? { isEmpty ? nil : self }
}
