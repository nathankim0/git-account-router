import Foundation
import GitAccountRouterCore

let path = CommandLine.arguments.dropFirst().first ?? FileManager.default.currentDirectoryPath
let runner = ProcessCommandRunner()

do {
  let git = try GitService(runner: runner)
  let github = try GitHubCLIService(runner: runner)
  let accounts = (try? await github.accounts()) ?? []
  let account = await git.currentAccount(
    at: path,
    activeHTTPSAccount: accounts.first(where: \.active)?.login
  )
  let branch = await git.branch(at: path)
  let remote = await git.originURL(at: path)

  if let account {
    print("GitHub @\(account) · \(branch ?? "detached") · \(remote ?? "no origin")")
  } else {
    print("GitHub account unresolved · \(branch ?? "not a Git repository")")
    exit(1)
  }
} catch {
  fputs("\(error.localizedDescription)\n", stderr)
  exit(1)
}
