import Foundation

public enum SSHConfigEditor {
  public static func alias(for account: String) -> String {
    let normalized = account.lowercased().map { character -> Character in
      character.isLetter || character.isNumber || character == "-" ? character : "-"
    }
    return "github-gar-\(String(normalized))"
  }

  public static func updating(
    content: String,
    account: String,
    identityFile: String
  ) throws -> String {
    let begin = "# >>> Git Account Router: \(account) >>>"
    let end = "# <<< Git Account Router: \(account) <<<"
    let lines = content.components(separatedBy: .newlines)
    let beginIndices = lines.indices.filter { lines[$0] == begin }
    let endIndices = lines.indices.filter { lines[$0] == end }

    guard beginIndices.count == endIndices.count, beginIndices.count <= 1 else {
      throw RouterError.malformedSSHConfig(account)
    }
    if let start = beginIndices.first, let finish = endIndices.first, finish < start {
      throw RouterError.malformedSSHConfig(account)
    }

    var preserved = lines
    if let start = beginIndices.first, let finish = endIndices.first {
      preserved.removeSubrange(start...finish)
    }
    while preserved.last?.isEmpty == true {
      preserved.removeLast()
    }

    let block = [
      begin,
      "Host \(alias(for: account))",
      "  HostName github.com",
      "  User git",
      "  IdentityFile \(identityFile)",
      "  IdentitiesOnly yes",
      end,
    ]

    return (preserved + (preserved.isEmpty ? [] : [""]) + block + [""]).joined(separator: "\n")
  }
}
