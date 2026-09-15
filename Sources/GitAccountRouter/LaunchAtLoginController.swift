import AppKit
import ServiceManagement

@MainActor
final class LaunchAtLoginController {
  var isEnabled: Bool {
    SMAppService.mainApp.status == .enabled
  }

  var statusDescription: String {
    switch SMAppService.mainApp.status {
    case .enabled:
      "로그인하면 Git Account Router가 자동으로 실행됩니다."
    case .requiresApproval:
      "시스템 설정의 로그인 항목에서 Git Account Router를 허용해야 합니다."
    case .notFound:
      "앱을 Applications 폴더로 옮긴 뒤 다시 설정하세요."
    case .notRegistered:
      "현재 자동 실행이 꺼져 있습니다."
    @unknown default:
      "자동 실행 상태를 확인할 수 없습니다."
    }
  }

  func setEnabled(_ enabled: Bool) throws {
    if enabled {
      if SMAppService.mainApp.status != .enabled {
        try SMAppService.mainApp.register()
      }
    } else if SMAppService.mainApp.status != .notRegistered {
      try SMAppService.mainApp.unregister()
    }
  }
}

@MainActor
final class SettingsWindowController: NSWindowController {
  private let launchAtLogin = LaunchAtLoginController()
  private let checkbox = NSButton(checkboxWithTitle: "로그인 시 실행", target: nil, action: nil)
  private let statusLabel = AppTheme.secondaryLabel("")

  init() {
    let controller = NSViewController()
    let window = NSWindow(
      contentRect: NSRect(x: 0, y: 0, width: 500, height: 250),
      styleMask: [.titled, .closable],
      backing: .buffered,
      defer: false
    )
    window.title = "Git Account Router 설정"
    window.contentViewController = controller
    super.init(window: window)
    window.center()
    build(in: controller)
  }

  @available(*, unavailable)
  required init?(coder: NSCoder) { nil }

  override func showWindow(_ sender: Any?) {
    refresh()
    super.showWindow(sender)
    window?.makeKeyAndOrderFront(sender)
    NSApp.activate(ignoringOtherApps: true)
  }

  private func build(in controller: NSViewController) {
    let root = NSView()
    controller.view = root

    let icon = NSImageView(
      image: NSImage(
        systemSymbolName: "person.crop.circle.badge.clock", accessibilityDescription: nil)
        ?? NSImage())
    icon.contentTintColor = AppTheme.indigo
    icon.translatesAutoresizingMaskIntoConstraints = false
    icon.widthAnchor.constraint(equalToConstant: 42).isActive = true
    icon.heightAnchor.constraint(equalToConstant: 42).isActive = true

    let title = AppTheme.label("일반", size: 22, weight: .bold)
    let intro = AppTheme.secondaryLabel(
      "메뉴 막대에서 프로젝트별 GitHub 계정을 바로 확인할 수 있습니다.", size: 13)
    intro.maximumNumberOfLines = 2

    checkbox.target = self
    checkbox.action = #selector(toggleLaunchAtLogin)
    checkbox.font = .systemFont(ofSize: 14, weight: .medium)
    statusLabel.maximumNumberOfLines = 2

    let text = NSStackView(views: [title, intro, checkbox, statusLabel])
    text.orientation = .vertical
    text.alignment = .leading
    text.spacing = 10

    let stack = NSStackView(views: [icon, text])
    stack.orientation = .horizontal
    stack.alignment = .top
    stack.spacing = 16
    root.addSubview(stack)
    stack.translatesAutoresizingMaskIntoConstraints = false

    NSLayoutConstraint.activate([
      stack.leadingAnchor.constraint(equalTo: root.leadingAnchor, constant: 28),
      stack.trailingAnchor.constraint(equalTo: root.trailingAnchor, constant: -28),
      stack.topAnchor.constraint(equalTo: root.topAnchor, constant: 30),
      stack.bottomAnchor.constraint(lessThanOrEqualTo: root.bottomAnchor, constant: -28),
      text.widthAnchor.constraint(equalTo: stack.widthAnchor, constant: -58),
    ])
    refresh()
  }

  private func refresh() {
    checkbox.state = launchAtLogin.isEnabled ? .on : .off
    statusLabel.stringValue = launchAtLogin.statusDescription
  }

  @objc private func toggleLaunchAtLogin() {
    do {
      try launchAtLogin.setEnabled(checkbox.state == .on)
      refresh()
    } catch {
      refresh()
      let alert = NSAlert(error: error)
      alert.messageText = "로그인 시 실행 설정을 변경하지 못했습니다"
      if let window {
        alert.beginSheetModal(for: window)
      } else {
        alert.runModal()
      }
    }
  }
}
