import Foundation

public struct AccountRoutingService: @unchecked Sendable {
  private let runner: any CommandRunning
  private let git: GitService
  private let github: GitHubCLIService
  private let fileManager: FileManager
  private let homeDirectory: String

  public init(
    runner: any CommandRunning,
    git: GitService,
    github: GitHubCLIService,
    fileManager: FileManager = .default,
    homeDirectory: String = NSHomeDirectory()
  ) {
    self.runner = runner
    self.git = git
    self.github = github
    self.fileManager = fileManager
    self.homeDirectory = homeDirectory
  }

  public func connect(projectPath: String, account: GitHubAccount) async throws -> RoutingOutcome {
    guard await git.isRepository(at: projectPath) else {
      throw RouterError.notGitRepository(projectPath)
    }
    guard let currentRemote = await git.originURL(at: projectPath) else {
      throw RouterError.missingOrigin(projectPath)
    }
    guard let parsedRemote = RemoteURLParser.parse(currentRemote),
      parsedRemote.host.contains("github")
    else {
      throw RouterError.unsupportedRemote(currentRemote)
    }

    let safeAccount = account.login.map { $0.isLetter || $0.isNumber || $0 == "-" ? $0 : "-" }
    let keyPath = "\(homeDirectory)/.ssh/id_ed25519_git_account_router_\(String(safeAccount))"
    let publicKeyPath = keyPath + ".pub"
    let alias = SSHConfigEditor.alias(for: account.login)
    let generatedKey = !fileManager.fileExists(atPath: keyPath)

    try fileManager.createDirectory(
      atPath: "\(homeDirectory)/.ssh",
      withIntermediateDirectories: true,
      attributes: [.posixPermissions: 0o700]
    )

    if generatedKey {
      let keygen = try await runner.run(
        executable: ToolLocator.find("ssh-keygen") ?? "/usr/bin/ssh-keygen",
        arguments: [
          "-q", "-t", "ed25519", "-C", "\(account.login)@git-account-router", "-f", keyPath, "-N",
          "",
        ]
      )
      guard keygen.exitCode == 0 else {
        throw RouterError.commandFailed(command: "ssh-keygen", output: keygen.combinedOutput)
      }
    }

    try updateSSHConfig(account: account.login, keyPath: keyPath)

    if await verifiedAccount(for: alias) != account.login {
      try await uploadKey(
        publicKeyPath: publicKeyPath,
        account: account,
        title: "Git Account Router on \(Host.current().localizedName ?? "Mac")"
      )
    }

    guard await verifiedAccount(for: alias) == account.login else {
      throw RouterError.accountVerificationFailed(account.login)
    }

    if await git.localConfig("git-account-router.original-origin", at: projectPath) == nil {
      try await git.setLocalConfig(
        "git-account-router.original-origin",
        value: currentRemote,
        at: projectPath
      )
    }

    let routedRemote = "git@\(alias):\(parsedRemote.repositoryPath).git"
    try await git.setOriginURL(routedRemote, at: projectPath)
    try await git.setLocalConfig(
      "git-account-router.account", value: account.login, at: projectPath)
    try await git.setLocalConfig("git-account-router.ssh-host", value: alias, at: projectPath)

    return RoutingOutcome(
      account: account.login,
      sshAlias: alias,
      remoteURL: routedRemote,
      generatedKey: generatedKey
    )
  }

  public func restoreOriginalRemote(projectPath: String) async throws {
    guard
      let original = await git.localConfig("git-account-router.original-origin", at: projectPath)
    else {
      throw RouterError.invalidData("복원할 원래 origin 주소가 없습니다.")
    }
    try await git.setOriginURL(original, at: projectPath)
    await git.removeLocalConfig("git-account-router.account", at: projectPath)
    await git.removeLocalConfig("git-account-router.ssh-host", at: projectPath)
    await git.removeLocalConfig("git-account-router.original-origin", at: projectPath)
  }

  private func updateSSHConfig(account: String, keyPath: String) throws {
    let configURL = URL(fileURLWithPath: "\(homeDirectory)/.ssh/config")
    let existing = (try? String(contentsOf: configURL, encoding: .utf8)) ?? ""
    let updated = try SSHConfigEditor.updating(
      content: existing,
      account: account,
      identityFile: keyPath
    )
    try updated.write(to: configURL, atomically: true, encoding: .utf8)
    try fileManager.setAttributes([.posixPermissions: 0o600], ofItemAtPath: configURL.path)
  }

  private func verifiedAccount(for alias: String) async -> String? {
    guard
      let result = try? await runner.run(
        executable: ToolLocator.find("ssh") ?? "/usr/bin/ssh",
        arguments: ["-o", "BatchMode=yes", "-o", "ConnectTimeout=10", "-T", "git@\(alias)"]
      )
    else {
      return nil
    }
    return GitHubIdentityParser.account(fromSSHOutput: result.combinedOutput)
  }

  private func uploadKey(
    publicKeyPath: String,
    account: GitHubAccount,
    title: String
  ) async throws {
    let accounts = try await github.accounts(hostname: account.host)
    let previous = accounts.first(where: \.active)?.login
    var switched = false

    do {
      if previous != account.login {
        try await github.switchAccount(to: account.login, hostname: account.host)
        switched = true
      }
      let upload = try await github.uploadSSHKey(path: publicKeyPath, title: title)
      if upload.exitCode != 0,
        !upload.combinedOutput.localizedCaseInsensitiveContains("already")
      {
        throw RouterError.commandFailed(command: "gh ssh-key add", output: upload.combinedOutput)
      }
    } catch {
      if switched, let previous {
        try? await github.switchAccount(to: previous, hostname: account.host)
      }
      throw error
    }

    if switched, let previous {
      try await github.switchAccount(to: previous, hostname: account.host)
    }
  }
}
