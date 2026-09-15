import AppKit
import GitAccountRouterCore

final class OnboardingViewController: NSViewController {
  private let model: AppModel
  private let onComplete: () -> Void
  private var step = 0
  private let pageContainer = NSView()
  private let progressStack = NSStackView()
  private let backButton = NSButton()
  private let nextButton = NSButton()

  init(model: AppModel, onComplete: @escaping () -> Void) {
    self.model = model
    self.onComplete = onComplete
    super.init(nibName: nil, bundle: nil)
  }

  @available(*, unavailable)
  required init?(coder: NSCoder) { nil }

  override func loadView() {
    view = GradientBackgroundView()
    buildLayout()
    render()
    model.observeChanges { [weak self] in self?.render() }
  }

  private func buildLayout() {
    progressStack.orientation = .horizontal
    progressStack.spacing = 8
    progressStack.alignment = .centerY

    let card = NSVisualEffectView()
    card.material = .hudWindow
    card.blendingMode = .withinWindow
    card.state = .active
    card.wantsLayer = true
    card.layer?.cornerRadius = 28
    card.layer?.masksToBounds = true
    card.addSubview(pageContainer)
    pageContainer.pinEdges(to: card, inset: 34)

    backButton.title = "이전"
    backButton.bezelStyle = .rounded
    backButton.controlSize = .large
    backButton.target = self
    backButton.action = #selector(goBack)

    nextButton.title = "계속"
    nextButton.bezelStyle = .rounded
    nextButton.controlSize = .large
    nextButton.keyEquivalent = "\r"
    nextButton.target = self
    nextButton.action = #selector(goNext)

    let spacer = NSView()
    let controls = NSStackView(views: [backButton, spacer, nextButton])
    controls.orientation = .horizontal
    controls.spacing = 12

    let outer = NSStackView(views: [progressStack, card, controls])
    outer.orientation = .vertical
    outer.spacing = 22
    outer.alignment = .centerX
    view.addSubview(outer)
    outer.translatesAutoresizingMaskIntoConstraints = false
    card.translatesAutoresizingMaskIntoConstraints = false
    controls.translatesAutoresizingMaskIntoConstraints = false
    spacer.translatesAutoresizingMaskIntoConstraints = false

    NSLayoutConstraint.activate([
      outer.centerXAnchor.constraint(equalTo: view.centerXAnchor),
      outer.centerYAnchor.constraint(equalTo: view.centerYAnchor),
      outer.widthAnchor.constraint(lessThanOrEqualToConstant: 720),
      outer.leadingAnchor.constraint(greaterThanOrEqualTo: view.leadingAnchor, constant: 40),
      outer.trailingAnchor.constraint(lessThanOrEqualTo: view.trailingAnchor, constant: -40),
      card.widthAnchor.constraint(equalTo: outer.widthAnchor),
      card.heightAnchor.constraint(equalToConstant: 470),
      controls.widthAnchor.constraint(equalTo: outer.widthAnchor),
      spacer.widthAnchor.constraint(greaterThanOrEqualToConstant: 300),
    ])
  }

  private func render() {
    renderProgress()
    for subview in pageContainer.subviews {
      subview.removeFromSuperview()
    }

    let page: NSView
    switch step {
    case 0: page = welcomePage()
    case 1: page = requirementsPage()
    case 2: page = accountsPage()
    default: page = projectsPage()
    }
    pageContainer.addSubview(page)
    page.pinEdges(to: pageContainer)

    backButton.isHidden = step == 0
    nextButton.title = step == 3 ? "시작하기" : "계속"
    nextButton.isEnabled = step != 1 || (model.hasGit && model.hasGitHubCLI)
  }

  private func renderProgress() {
    for subview in progressStack.arrangedSubviews {
      progressStack.removeArrangedSubview(subview)
      subview.removeFromSuperview()
    }
    for index in 0..<4 {
      let dot = NSView()
      dot.wantsLayer = true
      dot.layer?.backgroundColor =
        (index <= step ? AppTheme.cyan : NSColor.white.withAlphaComponent(0.2)).cgColor
      dot.layer?.cornerRadius = 3
      dot.translatesAutoresizingMaskIntoConstraints = false
      NSLayoutConstraint.activate([
        dot.heightAnchor.constraint(equalToConstant: 6),
        dot.widthAnchor.constraint(equalToConstant: index == step ? 48 : 20),
      ])
      progressStack.addArrangedSubview(dot)
    }
  }

  private func welcomePage() -> NSView {
    let icon = NSImageView(image: AppTheme.icon)
    icon.imageScaling = .scaleProportionallyUpOrDown
    icon.translatesAutoresizingMaskIntoConstraints = false
    NSLayoutConstraint.activate([
      icon.widthAnchor.constraint(equalToConstant: 150),
      icon.heightAnchor.constraint(equalToConstant: 150),
    ])

    let title = AppTheme.label("Git Account Router", size: 34, weight: .bold)
    title.alignment = .center
    let subtitle = AppTheme.label("프로젝트마다 올바른 GitHub 계정을 연결하세요", size: 19, weight: .medium)
    subtitle.alignment = .center
    subtitle.textColor = .secondaryLabelColor
    let body = AppTheme.secondaryLabel(
      "개인·회사 계정을 동시에 로그인해 두고, 저장소별 전용 SSH 키로 안전하게 분리합니다. GitHub CLI의 활성 계정을 바꿔도 프로젝트 연결은 흔들리지 않습니다.",
      size: 15
    )
    body.alignment = .center

    return centeredStack([icon, title, subtitle, body], spacing: 16)
  }

  private func requirementsPage() -> NSView {
    let title = AppTheme.label("필수 도구 확인", size: 28, weight: .bold)
    let git = requirementRow(
      title: "Git",
      detail: "프로젝트와 원격 주소를 안전하게 읽고 변경합니다.",
      installed: model.hasGit,
      command: "xcode-select --install"
    )
    let gh = requirementRow(
      title: "GitHub CLI",
      detail: "기기 인증과 SSH 공개키 등록에 사용합니다.",
      installed: model.hasGitHubCLI,
      command: "brew install gh"
    )
    let note = AppTheme.secondaryLabel("누락된 도구를 설치한 뒤 앱을 다시 실행하세요.")
    note.textColor = .systemOrange
    note.isHidden = model.hasGit && model.hasGitHubCLI
    return verticalStack([title, git, gh, note], spacing: 18)
  }

  private func accountsPage() -> NSView {
    let title = AppTheme.label("GitHub 계정 연결", size: 28, weight: .bold)
    let detail = AppTheme.secondaryLabel(
      "GitHub CLI가 인증 토큰을 macOS 키체인에 보관합니다. 이 앱은 토큰을 읽거나 저장하지 않습니다.")
    let accountStack = NSStackView()
    accountStack.orientation = .vertical
    accountStack.spacing = 10

    if model.accounts.isEmpty {
      accountStack.addArrangedSubview(
        AppTheme.secondaryLabel("아직 로그인된 계정이 없습니다. 기기 인증을 시작하세요.", size: 15))
    } else {
      for account in model.accounts {
        accountStack.addArrangedSubview(accountRow(account))
      }
    }

    let addButton = AppTheme.button("다른 GitHub 계정 추가", target: self, action: #selector(addAccount))
    addButton.image = NSImage(systemSymbolName: "person.badge.plus", accessibilityDescription: nil)
    let refresh = AppTheme.button("인증 완료 후 새로고침", target: self, action: #selector(refresh))
    return verticalStack([title, detail, accountStack, addButton, refresh], spacing: 16)
  }

  private func projectsPage() -> NSView {
    let title = AppTheme.label("첫 프로젝트 등록", size: 28, weight: .bold)
    let detail = AppTheme.secondaryLabel(
      "기존 Git 저장소뿐 아니라 새 폴더도 등록할 수 있습니다. Git 저장소가 아니면 초기화하기 전에 확인합니다.", size: 15)
    let list = NSStackView()
    list.orientation = .vertical
    list.spacing = 8

    for project in model.projects.prefix(3) {
      let row = AppTheme.card()
      let label = AppTheme.label("✓  \(project.displayName)", size: 15, weight: .semibold)
      row.contentView = label
      list.addArrangedSubview(row)
    }
    if model.projects.isEmpty {
      list.addArrangedSubview(AppTheme.secondaryLabel("아직 등록된 프로젝트가 없습니다."))
    }

    let addButton = AppTheme.button("프로젝트 폴더 선택", target: self, action: #selector(addProject))
    addButton.image = NSImage(systemSymbolName: "folder.badge.plus", accessibilityDescription: nil)
    let note = AppTheme.secondaryLabel("나중에 사이드바에서도 프로젝트를 계속 추가할 수 있습니다.", size: 12)
    return verticalStack([title, detail, list, addButton, note], spacing: 16)
  }

  private func requirementRow(title: String, detail: String, installed: Bool, command: String)
    -> NSView
  {
    let symbol = NSImageView(
      image: NSImage(
        systemSymbolName: installed ? "checkmark.circle.fill" : "exclamationmark.triangle.fill",
        accessibilityDescription: nil
      ) ?? NSImage())
    symbol.contentTintColor = installed ? .systemGreen : .systemOrange
    symbol.translatesAutoresizingMaskIntoConstraints = false
    symbol.widthAnchor.constraint(equalToConstant: 28).isActive = true

    let heading = AppTheme.label(
      "\(title)  ·  \(installed ? "설치됨" : "설치 필요")", size: 16, weight: .semibold)
    let description = AppTheme.secondaryLabel(detail)
    let commandLabel = AppTheme.label(command, size: 12)
    commandLabel.font = .monospacedSystemFont(ofSize: 12, weight: .regular)
    commandLabel.isHidden = installed
    let text = verticalStack([heading, description, commandLabel], spacing: 4)
    let row = NSStackView(views: [symbol, text])
    row.orientation = .horizontal
    row.alignment = .top
    row.spacing = 14

    let card = AppTheme.card()
    card.contentView = row
    return card
  }

  private func accountRow(_ account: GitHubAccount) -> NSView {
    let icon = NSImageView(
      image: NSImage(systemSymbolName: "person.crop.circle.fill", accessibilityDescription: nil)
        ?? NSImage())
    icon.contentTintColor = account.active ? AppTheme.indigo : .secondaryLabelColor
    let label = AppTheme.label("@\(account.login)", size: 15, weight: .semibold)
    let state = AppTheme.secondaryLabel(account.active ? "GitHub CLI 활성 계정" : "로그인됨")
    let text = verticalStack([label, state], spacing: 2)
    let row = NSStackView(views: [icon, text])
    row.orientation = .horizontal
    row.spacing = 12
    row.alignment = .centerY
    let card = AppTheme.card()
    card.contentView = row
    return card
  }

  private func verticalStack(_ views: [NSView], spacing: CGFloat) -> NSStackView {
    let stack = NSStackView(views: views)
    stack.orientation = .vertical
    stack.alignment = .leading
    stack.spacing = spacing
    stack.distribution = .gravityAreas
    return stack
  }

  private func centeredStack(_ views: [NSView], spacing: CGFloat) -> NSStackView {
    let stack = verticalStack(views, spacing: spacing)
    stack.alignment = .centerX
    return stack
  }

  @objc private func goBack() {
    step = max(0, step - 1)
    render()
  }

  @objc private func goNext() {
    if step == 3 {
      onComplete()
    } else {
      step += 1
      render()
    }
  }

  @objc private func addAccount() { model.launchDeviceLogin() }

  @objc private func refresh() {
    Task { await model.refreshAll() }
  }

  @objc private func addProject() {
    let panel = NSOpenPanel()
    panel.canChooseDirectories = true
    panel.canChooseFiles = false
    panel.prompt = "프로젝트 등록"
    if panel.runModal() == .OK, let url = panel.url {
      model.requestAddProject(at: url)
    }
  }
}

private final class GradientBackgroundView: NSView {
  override func draw(_ dirtyRect: NSRect) {
    super.draw(dirtyRect)
    let colors = [
      NSColor(srgbRed: 0.03, green: 0.05, blue: 0.13, alpha: 1),
      NSColor(srgbRed: 0.09, green: 0.08, blue: 0.23, alpha: 1),
      NSColor(srgbRed: 0.03, green: 0.16, blue: 0.18, alpha: 1),
    ]
    NSGradient(colors: colors)?.draw(in: bounds, angle: -35)
  }
}
