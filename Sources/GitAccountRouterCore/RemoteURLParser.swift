import Foundation

public struct GitRemote: Equatable, Sendable {
  public enum Transport: Equatable, Sendable {
    case ssh
    case https
  }

  public let host: String
  public let owner: String
  public let repository: String
  public let transport: Transport

  public var repositoryPath: String { "\(owner)/\(repository)" }

  public init(host: String, owner: String, repository: String, transport: Transport) {
    self.host = host
    self.owner = owner
    self.repository = repository
    self.transport = transport
  }
}

public enum RemoteURLParser {
  public static func parse(_ value: String) -> GitRemote? {
    if let url = URL(string: value), let scheme = url.scheme, let host = url.host {
      let transport: GitRemote.Transport
      switch scheme.lowercased() {
      case "https", "http": transport = .https
      case "ssh": transport = .ssh
      default: return nil
      }
      return build(host: host, path: url.path, transport: transport)
    }

    guard let colonIndex = value.firstIndex(of: ":") else { return nil }
    let hostPart = String(value[..<colonIndex])
    let path = String(value[value.index(after: colonIndex)...])
    let host = hostPart.split(separator: "@").last.map(String.init) ?? hostPart
    return build(host: host, path: path, transport: .ssh)
  }

  private static func build(host: String, path: String, transport: GitRemote.Transport)
    -> GitRemote?
  {
    var components = path.split(separator: "/").map(String.init)
    guard components.count == 2 else { return nil }
    if components[1].hasSuffix(".git") {
      components[1].removeLast(4)
    }
    guard !components[0].isEmpty, !components[1].isEmpty else { return nil }
    return GitRemote(
      host: host,
      owner: components[0],
      repository: components[1],
      transport: transport
    )
  }
}

public enum GitHubIdentityParser {
  public static func account(fromSSHOutput output: String) -> String? {
    guard let range = output.range(of: "Hi ") else { return nil }
    let suffix = output[range.upperBound...]
    guard let end = suffix.firstIndex(of: "!") else { return nil }
    let login = suffix[..<end].trimmingCharacters(in: .whitespacesAndNewlines)
    return login.isEmpty ? nil : login
  }
}
