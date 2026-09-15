import Foundation

public struct GitHubAccount: Codable, Hashable, Identifiable, Sendable {
  public var id: String { "\(host):\(login)" }
  public let host: String
  public let login: String
  public let active: Bool
  public let state: String
  public let gitProtocol: String?

  public init(
    host: String,
    login: String,
    active: Bool,
    state: String,
    gitProtocol: String? = nil
  ) {
    self.host = host
    self.login = login
    self.active = active
    self.state = state
    self.gitProtocol = gitProtocol
  }
}

public struct RegisteredProject: Codable, Hashable, Identifiable, Sendable {
  public let id: UUID
  public let path: String
  public var displayName: String
  public let addedAt: Date

  public init(id: UUID = UUID(), path: String, displayName: String, addedAt: Date = .now) {
    self.id = id
    self.path = path
    self.displayName = displayName
    self.addedAt = addedAt
  }
}

public struct ProjectSnapshot: Hashable, Sendable {
  public let projectID: UUID
  public let isRepository: Bool
  public let branch: String?
  public let remoteURL: String?
  public let connectedAccount: String?
  public let routingManaged: Bool

  public init(
    projectID: UUID,
    isRepository: Bool,
    branch: String? = nil,
    remoteURL: String? = nil,
    connectedAccount: String? = nil,
    routingManaged: Bool = false
  ) {
    self.projectID = projectID
    self.isRepository = isRepository
    self.branch = branch
    self.remoteURL = remoteURL
    self.connectedAccount = connectedAccount
    self.routingManaged = routingManaged
  }
}

public struct RoutingOutcome: Sendable {
  public let account: String
  public let sshAlias: String
  public let remoteURL: String
  public let generatedKey: Bool

  public init(account: String, sshAlias: String, remoteURL: String, generatedKey: Bool) {
    self.account = account
    self.sshAlias = sshAlias
    self.remoteURL = remoteURL
    self.generatedKey = generatedKey
  }
}

public enum RouterError: LocalizedError, Sendable {
  case commandFailed(command: String, output: String)
  case toolMissing(String)
  case notGitRepository(String)
  case missingOrigin(String)
  case unsupportedRemote(String)
  case malformedSSHConfig(String)
  case accountVerificationFailed(String)
  case invalidData(String)

  public var errorDescription: String? {
    switch self {
    case .commandFailed(let command, let output):
      "명령 실행에 실패했습니다: \(command)\n\(output)"
    case .toolMissing(let tool):
      "필수 도구를 찾을 수 없습니다: \(tool)"
    case .notGitRepository(let path):
      "Git 저장소가 아닙니다: \(path)"
    case .missingOrigin(let path):
      "origin 원격 저장소가 없습니다: \(path)"
    case .unsupportedRemote(let remote):
      "지원하지 않는 GitHub 원격 주소입니다: \(remote)"
    case .malformedSSHConfig(let message):
      "SSH 설정의 관리 블록이 손상되었습니다: \(message)"
    case .accountVerificationFailed(let account):
      "SSH 연결이 @\(account) 계정으로 확인되지 않았습니다."
    case .invalidData(let message):
      message
    }
  }
}
