import AppKit

@MainActor
@main
final class AppDelegate: NSObject, NSApplicationDelegate {
  private let model = AppModel()
  private var window: NSWindow!
  private var rootController: NSViewController!
  private var statusBarController: StatusBarController!
  private var settingsWindowController: SettingsWindowController!

  static func main() {
    let app = NSApplication.shared
    let delegate = AppDelegate()
    app.delegate = delegate
    app.setActivationPolicy(.regular)
    app.run()
  }

  func applicationDidFinishLaunching(_ notification: Notification) {
    NSApplication.shared.applicationIconImage = AppTheme.icon
    configureMenu()
    configureModelCallbacks()
    showInitialInterface()
    statusBarController = StatusBarController(
      model: model,
      showApplication: { [weak self] in self?.showApplicationWindow() },
      showSettings: { [weak self] in self?.showSettings(nil) }
    )
    model.start()
    NSApplication.shared.activate(ignoringOtherApps: true)
    captureLayoutSnapshotIfRequested()
  }

  func applicationShouldTerminateAfterLastWindowClosed(_ sender: NSApplication) -> Bool {
    false
  }

  func applicationDidBecomeActive(_ notification: Notification) {
    if window == nil || !window.isVisible {
      showApplicationWindow()
    }
  }

  func applicationShouldHandleReopen(_ sender: NSApplication, hasVisibleWindows flag: Bool) -> Bool
  {
    showApplicationWindow()
    return true
  }

  func application(_ app: NSApplication, shouldRestoreApplicationState coder: NSCoder) -> Bool {
    false
  }

  func application(_ app: NSApplication, shouldSaveApplicationState coder: NSCoder) -> Bool {
    false
  }

  private func showInitialInterface() {
    #if DEBUG
      if ProcessInfo.processInfo.environment["GAR_SKIP_ONBOARDING"] == "1" {
        showMainInterface()
        return
      }
    #endif
    if UserDefaults.standard.bool(forKey: "onboardingCompleted") {
      showMainInterface()
    } else {
      let onboarding = OnboardingViewController(model: model) { [weak self] in
        UserDefaults.standard.set(true, forKey: "onboardingCompleted")
        self?.showMainInterface()
      }
      setRoot(onboarding, size: NSSize(width: 980, height: 680))
    }
  }

  private func showMainInterface() {
    let main = MainViewController(model: model)
    setRoot(main, size: NSSize(width: 1120, height: 720))
  }

  private func setRoot(_ controller: NSViewController, size: NSSize) {
    rootController = controller
    if window == nil {
      window = NSWindow(
        contentRect: NSRect(origin: .zero, size: size),
        styleMask: [.titled, .closable, .miniaturizable, .resizable, .fullSizeContentView],
        backing: .buffered,
        defer: false
      )
      window.title = "Git Account Router"
      window.titlebarAppearsTransparent = true
      window.isRestorable = false
    }
    controller.preferredContentSize = size
    window.contentViewController = controller
    window.contentMinSize = NSSize(width: 760, height: 520)
    window.minSize =
      window.frameRect(
        forContentRect: NSRect(origin: .zero, size: window.contentMinSize)
      ).size
    window.setContentSize(size)
    window.center()
    window.makeKeyAndOrderFront(nil)
    DispatchQueue.main.async { [weak self] in
      guard let self, self.rootController === controller else { return }
      self.window.setContentSize(size)
      self.window.center()
      self.window.makeKeyAndOrderFront(nil)
    }
  }

  private func showApplicationWindow() {
    if window == nil {
      showInitialInterface()
    }
    window.makeKeyAndOrderFront(nil)
    NSApplication.shared.activate(ignoringOtherApps: true)
  }

  @objc func showSettings(_ sender: Any?) {
    if settingsWindowController == nil {
      settingsWindowController = SettingsWindowController()
    }
    settingsWindowController.showWindow(sender)
  }

  private func configureModelCallbacks() {
    model.onAlert = { [weak self] title, message in
      guard let self else { return }
      let alert = NSAlert()
      alert.messageText = title
      alert.informativeText = message
      alert.addButton(withTitle: "확인")
      if let window {
        alert.beginSheetModal(for: window)
      } else {
        alert.runModal()
      }
    }
    model.onInitializationRequested = { [weak self] path in
      guard let self, let window else { return }
      let alert = NSAlert()
      alert.messageText = "Git 저장소로 초기화할까요?"
      alert.informativeText = "\(path)\n\n소스 파일은 건드리지 않고 main 브랜치로 초기화합니다."
      alert.addButton(withTitle: "Git 저장소 만들기")
      alert.addButton(withTitle: "취소")
      alert.beginSheetModal(for: window) { response in
        if response == .alertFirstButtonReturn {
          self.model.initializeRepository(at: path)
        }
      }
    }
    model.observeChanges { [weak self] in
      self?.restoreWindowMinimumSizeIfNeeded()
    }
  }

  private func restoreWindowMinimumSizeIfNeeded() {
    guard let window, window.frame.width < 760 || window.frame.height < 520 else { return }
    let contentSize = rootController?.preferredContentSize ?? NSSize(width: 1120, height: 720)
    window.setContentSize(contentSize)
    window.center()
    window.makeKeyAndOrderFront(nil)
  }

  private func configureMenu() {
    let mainMenu = NSMenu()
    let appItem = NSMenuItem()
    mainMenu.addItem(appItem)
    let appMenu = NSMenu()
    appMenu.addItem(
      withTitle: "Git Account Router 정보",
      action: #selector(NSApplication.orderFrontStandardAboutPanel(_:)), keyEquivalent: "")
    let settings = NSMenuItem(
      title: "설정…", action: #selector(showSettings(_:)), keyEquivalent: ",")
    settings.target = self
    appMenu.addItem(settings)
    appMenu.addItem(.separator())
    appMenu.addItem(
      withTitle: "Git Account Router 종료", action: #selector(NSApplication.terminate(_:)),
      keyEquivalent: "q")
    appItem.submenu = appMenu
    NSApplication.shared.mainMenu = mainMenu
  }

  private func captureLayoutSnapshotIfRequested() {
    guard let path = ProcessInfo.processInfo.environment["GAR_LAYOUT_SNAPSHOT"] else { return }
    let delay = Double(ProcessInfo.processInfo.environment["GAR_LAYOUT_SNAPSHOT_DELAY"] ?? "1") ?? 1
    DispatchQueue.main.asyncAfter(deadline: .now() + delay) { [weak self] in
      guard let view = self?.window.contentView else { return }
      view.layoutSubtreeIfNeeded()
      guard let bitmap = view.bitmapImageRepForCachingDisplay(in: view.bounds) else { return }
      view.cacheDisplay(in: view.bounds, to: bitmap)
      guard let data = bitmap.representation(using: .png, properties: [:]) else { return }
      try? data.write(to: URL(fileURLWithPath: path))
      NSApp.terminate(nil)
    }
  }
}
