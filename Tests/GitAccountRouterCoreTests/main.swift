import Foundation
import GitAccountRouterCore

enum TestFailure: Error {
  case failed(String)
}

func expect(_ condition: @autoclosure () -> Bool, _ message: String) throws {
  guard condition() else { throw TestFailure.failed(message) }
}

do {
  try expect(
    RemoteURLParser.parse("https://github.com/nathankim0/example.git")
      == GitRemote(
        host: "github.com", owner: "nathankim0", repository: "example", transport: .https),
    "HTTPS remote parsing"
  )
  try expect(
    RemoteURLParser.parse("git@github-gar-nathankim0:nathankim0/example.git")
      == GitRemote(
        host: "github-gar-nathankim0",
        owner: "nathankim0",
        repository: "example",
        transport: .ssh
      ),
    "SSH alias parsing"
  )
  try expect(RemoteURLParser.parse("not-a-remote") == nil, "Invalid remote rejection")

  let original = "Host work\n  HostName example.com\n  User git\n"
  let first = try SSHConfigEditor.updating(
    content: original,
    account: "nathankim0",
    identityFile: "/old/key"
  )
  let second = try SSHConfigEditor.updating(
    content: first,
    account: "nathankim0",
    identityFile: "/new/key"
  )
  try expect(second.contains("Host work"), "Unrelated SSH host preservation")
  try expect(second.contains("IdentityFile /new/key"), "Managed key update")
  try expect(!second.contains("IdentityFile /old/key"), "Old managed key removal")
  try expect(
    second.components(separatedBy: "# >>> Git Account Router: nathankim0 >>>").count == 2,
    "Managed block idempotency"
  )

  let broken = "# >>> Git Account Router: me >>>\nHost github-gar-me\n"
  var rejectedMalformedBlock = false
  do {
    _ = try SSHConfigEditor.updating(content: broken, account: "me", identityFile: "/key")
  } catch {
    rejectedMalformedBlock = true
  }
  try expect(rejectedMalformedBlock, "Malformed block rejection")

  let greeting =
    "Hi nathankim0! You've successfully authenticated, but GitHub does not provide shell access."
  try expect(
    GitHubIdentityParser.account(fromSSHOutput: greeting) == "nathankim0", "SSH identity parsing")
  try expect(
    GitHubIdentityParser.account(fromSSHOutput: "Permission denied") == nil, "SSH error rejection")

  print("All Git Account Router core tests passed.")
} catch {
  fputs("Test failed: \(error)\n", stderr)
  exit(1)
}
