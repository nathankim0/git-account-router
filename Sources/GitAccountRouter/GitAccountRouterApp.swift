import AppKit

@MainActor
@main
final class AppDelegate: NSObject, NSApplicationDelegate {
  private let model = AppModel()
  private var window: NSWindow!
  private var rootController: NSViewController!

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
    model.start()
    NSApplication.shared.activate(ignoringOtherApps: true)
  }

  func applicationShouldTerminateAfterLastWindowClosed(_ sender: NSApplication) -> Bool {
    true
  }

  private func showInitialInterface() {
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
      window.center()
    }
    window.setContentSize(size)
    window.contentViewController = controller
    window.makeKeyAndOrderFront(nil)
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
  }

  private func configureMenu() {
    let mainMenu = NSMenu()
    let appItem = NSMenuItem()
    mainMenu.addItem(appItem)
    let appMenu = NSMenu()
    appMenu.addItem(
      withTitle: "Git Account Router 정보",
      action: #selector(NSApplication.orderFrontStandardAboutPanel(_:)), keyEquivalent: "")
    appMenu.addItem(.separator())
    appMenu.addItem(
      withTitle: "Git Account Router 종료", action: #selector(NSApplication.terminate(_:)),
      keyEquivalent: "q")
    appItem.submenu = appMenu
    NSApplication.shared.mainMenu = mainMenu
  }
}
