import AppKit
import GitAccountRouterCore

@MainActor
final class StatusBarController: NSObject {
  private let model: AppModel
  private let showApplication: () -> Void
  private let showSettings: () -> Void
  private let statusItem = NSStatusBar.system.statusItem(withLength: NSStatusItem.variableLength)

  init(model: AppModel, showApplication: @escaping () -> Void, showSettings: @escaping () -> Void) {
    self.model = model
    self.showApplication = showApplication
    self.showSettings = showSettings
    super.init()

    if let button = statusItem.button {
      button.image = NSImage(
        systemSymbolName: "arrow.triangle.branch", accessibilityDescription: "Git Account Router")
      button.imagePosition = .imageLeading
    }
    model.observeChanges { [weak self] in self?.refresh() }
    refresh()
  }

  private func refresh() {
    let snapshot = model.selectedProjectID.flatMap { model.snapshots[$0] }
    if let account = snapshot?.connectedAccount {
      statusItem.button?.title = "@\(account)"
    } else if let account = model.activeAccount?.login {
      statusItem.button?.title = "@\(account)"
    } else {
      statusItem.button?.title = "Git"
    }
    statusItem.menu = makeMenu(snapshot: snapshot)
  }

  private func makeMenu(snapshot: ProjectSnapshot?) -> NSMenu {
    let menu = NSMenu()
    let selectedName = model.selectedProject?.displayName ?? "선택한 프로젝트 없음"
    let accountText = snapshot?.connectedAccount.map { "@\($0)" } ?? "계정 확인 필요"
    let summary = NSMenuItem(
      title: "\(selectedName)  ·  \(accountText)", action: nil, keyEquivalent: "")
    summary.isEnabled = false
    menu.addItem(summary)
    menu.addItem(.separator())

    if !model.projects.isEmpty {
      let projectsItem = NSMenuItem(title: "프로젝트 선택", action: nil, keyEquivalent: "")
      let projectsMenu = NSMenu()
      for project in model.projects {
        let projectSnapshot = model.snapshots[project.id]
        let account = projectSnapshot?.connectedAccount.map { "  @\($0)" } ?? ""
        let item = NSMenuItem(
          title: project.displayName + account,
          action: #selector(selectProject(_:)),
          keyEquivalent: ""
        )
        item.target = self
        item.representedObject = project.id.uuidString
        item.state = project.id == model.selectedProjectID ? .on : .off
        projectsMenu.addItem(item)
      }
      projectsItem.submenu = projectsMenu
      menu.addItem(projectsItem)
    }

    menu.addItem(
      item(title: "Git Account Router 열기", action: #selector(openApplication), key: ""))
    menu.addItem(item(title: "새로고침", action: #selector(refreshAccounts), key: "r"))
    menu.addItem(.separator())
    menu.addItem(item(title: "설정…", action: #selector(openSettings), key: ","))
    menu.addItem(.separator())
    menu.addItem(
      item(title: "Git Account Router 종료", action: #selector(terminate), key: "q"))
    return menu
  }

  private func item(title: String, action: Selector, key: String) -> NSMenuItem {
    let item = NSMenuItem(title: title, action: action, keyEquivalent: key)
    item.target = self
    return item
  }

  @objc private func selectProject(_ sender: NSMenuItem) {
    guard let value = sender.representedObject as? String, let id = UUID(uuidString: value) else {
      return
    }
    model.selectProject(id)
    showApplication()
  }

  @objc private func openApplication() { showApplication() }
  @objc private func openSettings() { showSettings() }
  @objc private func refreshAccounts() { Task { await model.refreshAll() } }
  @objc private func terminate() { NSApp.terminate(nil) }
}
