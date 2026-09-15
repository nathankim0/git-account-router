import AppKit
import Foundation
import GitAccountRouterCore

@MainActor
final class AppModel {
  private(set) var accounts: [GitHubAccount] = []
  private(set) var projects: [RegisteredProject] = []
  private(set) var snapshots: [UUID: ProjectSnapshot] = [:]
  var selectedProjectID: UUID?
  private(set) var isBusy = false

  var onAlert: ((String, String) -> Void)?
  var onInitializationRequested: ((String) -> Void)?

  private var changeObservers: [() -> Void] = []

  private let runner = ProcessCommandRunner()
  private let registry = ProjectRegistry()
  private var git: GitService?
  private var github: GitHubCLIService?
  private var router: AccountRoutingService?

  var hasGit: Bool { git != nil }
  var hasGitHubCLI: Bool { github != nil }
  var activeAccount: GitHubAccount? { accounts.first(where: \.active) }
  var selectedProject: RegisteredProject? {
    guard let selectedProjectID else { return nil }
    return projects.first { $0.id == selectedProjectID }
  }

  init() {
    configureServices()
  }

  func observeChanges(_ observer: @escaping () -> Void) {
    changeObservers.append(observer)
  }

  func start() {
    setBusy(true)
    Task {
      do {
        projects = try await registry.load()
        selectedProjectID = projects.first?.id
        await refreshAll()
      } catch {
        show(error)
      }
      setBusy(false)
    }
  }

  func refreshAll() async {
    guard let git else { return }
    setBusy(true)
    do {
      if let github {
        accounts = try await github.accounts()
      }
      let activeLogin = accounts.first(where: \.active)?.login
      var values: [UUID: ProjectSnapshot] = [:]
      for project in projects {
        values[project.id] = await git.snapshot(for: project, activeHTTPSAccount: activeLogin)
      }
      snapshots = values
    } catch {
      show(error)
    }
    setBusy(false)
    notify()
  }

  func requestAddProject(at url: URL) {
    guard let git else { return }
    setBusy(true)
    Task {
      if await git.isRepository(at: url.path) {
        await registerRepository(at: url.path)
      } else {
        onInitializationRequested?(url.path)
      }
      setBusy(false)
    }
  }

  func initializeRepository(at path: String) {
    guard let git else { return }
    setBusy(true)
    Task {
      do {
        try await git.initializeRepository(at: path)
        await registerRepository(at: path)
      } catch {
        show(error)
      }
      setBusy(false)
    }
  }

  func removeProject(_ project: RegisteredProject) {
    projects.removeAll { $0.id == project.id }
    snapshots[project.id] = nil
    selectedProjectID = projects.first?.id
    persistProjects()
    notify()
  }

  func selectProject(_ id: UUID?) {
    selectedProjectID = id
    notify()
  }

  func setOrigin(_ value: String, for project: RegisteredProject) {
    guard let git else { return }
    setBusy(true)
    Task {
      do {
        guard RemoteURLParser.parse(value) != nil else {
          throw RouterError.unsupportedRemote(value)
        }
        try await git.setOriginURL(value, at: project.path)
        await refreshAll()
      } catch {
        show(error)
      }
      setBusy(false)
    }
  }

  func connect(_ project: RegisteredProject, to account: GitHubAccount) {
    guard let router else { return }
    setBusy(true)
    Task {
      do {
        let outcome = try await router.connect(projectPath: project.path, account: account)
        await refreshAll()
        present(
          "연결 완료",
          "\(project.displayName)의 origin이 @\(outcome.account) 전용 SSH 연결로 변경되었습니다."
        )
      } catch {
        show(error)
      }
      setBusy(false)
    }
  }

  func restoreOriginalRemote(for project: RegisteredProject) {
    guard let router else { return }
    setBusy(true)
    Task {
      do {
        try await router.restoreOriginalRemote(projectPath: project.path)
        await refreshAll()
      } catch {
        show(error)
      }
      setBusy(false)
    }
  }

  func launchDeviceLogin() {
    guard let github else {
      present("GitHub CLI 필요", "먼저 GitHub CLI를 설치하세요: brew install gh")
      return
    }
    Task {
      do {
        try await github.launchDeviceLoginInTerminal()
        present(
          "기기 인증을 시작했습니다",
          "Terminal과 브라우저에서 대상 계정으로 승인한 뒤 앱에서 새로고침하세요. 일회용 코드는 클립보드에도 복사됩니다."
        )
      } catch {
        show(error)
      }
    }
  }

  func switchCLIAccount(to account: GitHubAccount) {
    guard let github else { return }
    setBusy(true)
    Task {
      do {
        try await github.switchAccount(to: account.login, hostname: account.host)
        await refreshAll()
      } catch {
        show(error)
      }
      setBusy(false)
    }
  }

  func installStatusHelper() {
    guard let source = Bundle.main.resourceURL?.appendingPathComponent("git-account-status"),
      FileManager.default.fileExists(atPath: source.path)
    else {
      present("Release 앱에서 사용 가능", "git-account-status는 DMG 배포 앱에 포함됩니다.")
      return
    }

    do {
      let directory = URL(fileURLWithPath: NSHomeDirectory()).appendingPathComponent(".local/bin")
      try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
      let destination = directory.appendingPathComponent("git-account-status")
      if FileManager.default.fileExists(atPath: destination.path) {
        try FileManager.default.removeItem(at: destination)
      }
      try FileManager.default.copyItem(at: source, to: destination)
      try FileManager.default.setAttributes(
        [.posixPermissions: 0o755], ofItemAtPath: destination.path)
      present("설치 완료", "터미널에서 git-account-status를 실행하면 현재 프로젝트의 GitHub 계정을 확인할 수 있습니다.")
    } catch {
      show(error)
    }
  }

  func reveal(_ project: RegisteredProject) {
    NSWorkspace.shared.selectFile(nil, inFileViewerRootedAtPath: project.path)
  }

  private func configureServices() {
    do {
      let git = try GitService(runner: runner)
      self.git = git
      if let github = try? GitHubCLIService(runner: runner) {
        self.github = github
        router = AccountRoutingService(runner: runner, git: git, github: github)
      }
    } catch {
      show(error)
    }
  }

  private func registerRepository(at path: String) async {
    guard let git else { return }
    do {
      let root = try await git.repositoryRoot(at: path)
      if let existing = projects.first(where: { $0.path == root }) {
        selectedProjectID = existing.id
        notify()
        return
      }
      let project = RegisteredProject(
        path: root,
        displayName: URL(fileURLWithPath: root).lastPathComponent
      )
      projects.append(project)
      projects.sort {
        $0.displayName.localizedCaseInsensitiveCompare($1.displayName) == .orderedAscending
      }
      selectedProjectID = project.id
      persistProjects()
      await refreshAll()
    } catch {
      show(error)
    }
  }

  private func persistProjects() {
    let value = projects
    Task {
      do {
        try await registry.save(value)
      } catch {
        show(error)
      }
    }
  }

  private func setBusy(_ value: Bool) {
    isBusy = value
    notify()
  }

  private func notify() {
    for observer in changeObservers {
      observer()
    }
  }

  private func present(_ title: String, _ message: String) {
    onAlert?(title, message)
  }

  private func show(_ error: Error) {
    present("작업을 완료하지 못했습니다", error.localizedDescription)
  }
}
