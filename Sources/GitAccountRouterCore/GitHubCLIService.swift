import Foundation

public struct GitHubCLIService: Sendable {
  private struct AuthStatus: Decodable {
    let hosts: [String: [AccountRecord]]
  }

  private struct AccountRecord: Decodable {
    let login: String
    let active: Bool
    let state: String
    let gitProtocol: String?
  }

  private let runner: any CommandRunning
  public let executable: String

  public init(runner: any CommandRunning, executable: String? = nil) throws {
    guard let resolved = executable ?? ToolLocator.find("gh") else {
      throw RouterError.toolMissing("GitHub CLI (gh)")
    }
    self.runner = runner
    self.executable = resolved
  }

  public func accounts(hostname: String = "github.com") async throws -> [GitHubAccount] {
    let result = try await runner.run(
      executable: executable,
      arguments: ["auth", "status", "--hostname", hostname, "--json", "hosts"]
    )
    guard result.exitCode == 0 else {
      throw RouterError.commandFailed(command: "gh auth status", output: result.combinedOutput)
    }

    let data = Data(result.standardOutput.utf8)
    let status = try JSONDecoder().decode(AuthStatus.self, from: data)
    return (status.hosts[hostname] ?? []).map {
      GitHubAccount(
        host: hostname,
        login: $0.login,
        active: $0.active,
        state: $0.state,
        gitProtocol: $0.gitProtocol
      )
    }
  }

  public func switchAccount(to login: String, hostname: String = "github.com") async throws {
    let result = try await runner.run(
      executable: executable,
      arguments: ["auth", "switch", "--hostname", hostname, "--user", login]
    )
    guard result.exitCode == 0 else {
      throw RouterError.commandFailed(command: "gh auth switch", output: result.combinedOutput)
    }
  }

  public func uploadSSHKey(path: String, title: String) async throws -> CommandResult {
    try await runner.run(
      executable: executable,
      arguments: ["ssh-key", "add", path, "--title", title]
    )
  }

  public func launchDeviceLoginInTerminal(hostname: String = "github.com") async throws {
    let command = [
      shellQuote(executable),
      "auth login",
      "--hostname \(shellQuote(hostname))",
      "--git-protocol https",
      "--web",
      "--clipboard",
      "--scopes repo,workflow,admin:public_key",
      "; printf '\\nAuthentication finished. You can return to Git Account Router.\\n'",
    ].joined(separator: " ")
    let script =
      "tell application \"Terminal\" to do script \"\(appleScriptEscape(command))\"\ntell application \"Terminal\" to activate"
    let result = try await runner.run(
      executable: "/usr/bin/osascript",
      arguments: ["-e", script]
    )
    guard result.exitCode == 0 else {
      throw RouterError.commandFailed(command: "Open device login", output: result.combinedOutput)
    }
  }

  private func shellQuote(_ value: String) -> String {
    "'" + value.replacingOccurrences(of: "'", with: "'\\''") + "'"
  }

  private func appleScriptEscape(_ value: String) -> String {
    value
      .replacingOccurrences(of: "\\", with: "\\\\")
      .replacingOccurrences(of: "\"", with: "\\\"")
  }
}
