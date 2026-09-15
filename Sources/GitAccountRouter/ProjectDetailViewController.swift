import AppKit
import GitAccountRouterCore

final class ProjectDetailViewController: NSViewController {
  private let model: AppModel
  private var project: RegisteredProject?
  private let contentStack = NSStackView()

  init(model: AppModel) {
    self.model = model
    super.init(nibName: nil, bundle: nil)
  }

  @available(*, unavailable)
  required init?(coder: NSCoder) { nil }

  override func loadView() {
    view = NSView()
    let scroll = NSScrollView()
    scroll.hasVerticalScroller = true
    scroll.drawsBackground = false
    let document = NSView()
    scroll.documentView = document

    contentStack.orientation = .vertical
    contentStack.alignment = .leading
    contentStack.spacing = 20
    document.addSubview(contentStack)
    contentStack.translatesAutoresizingMaskIntoConstraints = false
    view.addSubview(scroll)
    scroll.pinEdges(to: view)

    NSLayoutConstraint.activate([
      contentStack.leadingAnchor.constraint(equalTo: document.leadingAnchor, constant: 34),
      contentStack.trailingAnchor.constraint(equalTo: document.trailingAnchor, constant: -34),
      contentStack.topAnchor.constraint(equalTo: document.topAnchor, constant: 34),
      contentStack.bottomAnchor.constraint(lessThanOrEqualTo: document.bottomAnchor, constant: -34),
      contentStack.widthAnchor.constraint(equalTo: scroll.contentView.widthAnchor, constant: -68),
    ])
  }

  func show(project: RegisteredProject?) {
    self.project = project
    for subview in contentStack.arrangedSubviews {
      contentStack.removeArrangedSubview(subview)
      subview.removeFromSuperview()
    }
    guard let project else {
      contentStack.addArrangedSubview(emptyState())
      return
    }
    let snapshot = model.snapshots[project.id]
    let sections = [
      header(project, snapshot: snapshot),
      accountCard(project, snapshot: snapshot),
      remoteCard(project, snapshot: snapshot),
      safetyCard(project, snapshot: snapshot),
    ]
    for section in sections {
      contentStack.addArrangedSubview(section)
    }
    for arrangedView in contentStack.arrangedSubviews {
      arrangedView.translatesAutoresizingMaskIntoConstraints = false
      arrangedView.widthAnchor.constraint(equalTo: contentStack.widthAnchor).isActive = true
    }
  }

  private func emptyState() -> NSView {
    let image = NSImageView(
      image: NSImage(systemSymbolName: "arrow.triangle.branch", accessibilityDescription: nil)
        ?? NSImage())
    image.contentTintColor = AppTheme.indigo
    image.translatesAutoresizingMaskIntoConstraints = false
    image.widthAnchor.constraint(equalToConstant: 64).isActive = true
    image.heightAnchor.constraint(equalToConstant: 64).isActive = true
    let title = AppTheme.label("프로젝트를 선택하세요", size: 26, weight: .bold)
    let detail = AppTheme.secondaryLabel("어떤 GitHub 계정으로 연결되어 있는지 확인하고 안전하게 전환할 수 있습니다.", size: 15)
    let stack = NSStackView(views: [image, title, detail])
    stack.orientation = .vertical
    stack.alignment = .centerX
    stack.spacing = 12
    return stack
  }

  private func header(_ project: RegisteredProject, snapshot: ProjectSnapshot?) -> NSView {
    let icon = NSImageView(
      image: NSImage(systemSymbolName: "shippingbox.fill", accessibilityDescription: nil)
        ?? NSImage())
    icon.contentTintColor = AppTheme.indigo
    icon.translatesAutoresizingMaskIntoConstraints = false
    icon.widthAnchor.constraint(equalToConstant: 58).isActive = true
    icon.heightAnchor.constraint(equalToConstant: 58).isActive = true

    let name = AppTheme.label(project.displayName, size: 30, weight: .bold)
    let path = AppTheme.secondaryLabel(project.path, size: 12)
    path.font = .monospacedSystemFont(ofSize: 12, weight: .regular)
    path.lineBreakMode = .byTruncatingMiddle
    let metadata = AppTheme.secondaryLabel(
      [
        snapshot?.branch.map { "Branch: \($0)" },
        snapshot?.routingManaged == true ? "Project-specific SSH" : nil,
      ]
      .compactMap { $0 }
      .joined(separator: "  ·  "),
      size: 12
    )
    let text = vertical([name, path, metadata], spacing: 5)
    let reveal = AppTheme.button("Finder에서 보기", target: self, action: #selector(revealProject))
    let row = NSStackView(views: [icon, text, NSView(), reveal])
    row.orientation = .horizontal
    row.alignment = .top
    row.spacing = 16
    return row
  }

  private func accountCard(_ project: RegisteredProject, snapshot: ProjectSnapshot?) -> NSView {
    let card = AppTheme.card()
    let title = AppTheme.label("Account Routing", size: 17, weight: .semibold)
    let current = AppTheme.label(
      snapshot?.connectedAccount.map { "현재 연결  @\($0)" } ?? "현재 연결  확인되지 않음",
      size: 15,
      weight: .medium
    )
    current.textColor = snapshot?.connectedAccount == nil ? .systemOrange : .labelColor

    let popup = NSPopUpButton()
    popup.identifier = NSUserInterfaceItemIdentifier("accountPopup")
    popup.addItem(withTitle: "변경할 GitHub 계정 선택")
    for account in model.accounts {
      popup.addItem(withTitle: "@\(account.login)")
      popup.lastItem?.representedObject = account.id
    }
    if let connected = snapshot?.connectedAccount,
      let index = model.accounts.firstIndex(where: { $0.login == connected })
    {
      popup.selectItem(at: index + 1)
    }

    let connect = AppTheme.button("선택한 계정으로 연결", target: self, action: #selector(connectAccount))
    connect.identifier = NSUserInterfaceItemIdentifier("connectButton")
    let hint = AppTheme.secondaryLabel("GitHub CLI의 전역 활성 계정과 무관하게 이 프로젝트에만 적용됩니다.", size: 12)
    let controls = NSStackView(views: [popup, NSView(), connect])
    controls.orientation = .horizontal
    controls.spacing = 12
    let stack = vertical([title, current, controls, hint], spacing: 12)
    card.contentView = stack
    return card
  }

  private func remoteCard(_ project: RegisteredProject, snapshot: ProjectSnapshot?) -> NSView {
    let card = AppTheme.card()
    let title = AppTheme.label("Remote Origin", size: 17, weight: .semibold)
    let field = NSTextField(string: snapshot?.remoteURL ?? "")
    field.identifier = NSUserInterfaceItemIdentifier("remoteField")
    field.placeholderString = "https://github.com/owner/repository.git"
    field.font = .monospacedSystemFont(ofSize: 13, weight: .regular)
    let save = AppTheme.button("origin 저장", target: self, action: #selector(saveOrigin))
    let controls = NSStackView(views: [field, save])
    controls.orientation = .horizontal
    controls.spacing = 10
    let hint = AppTheme.secondaryLabel(
      snapshot?.remoteURL == nil
        ? "origin이 없는 새 프로젝트입니다. GitHub 저장소 주소를 입력하세요."
        : "SSH와 HTTPS 형식의 GitHub 주소를 지원합니다.",
      size: 12
    )
    let stack = vertical([title, controls, hint], spacing: 10)
    card.contentView = stack
    return card
  }

  private func safetyCard(_ project: RegisteredProject, snapshot: ProjectSnapshot?) -> NSView {
    let card = AppTheme.card()
    card.fillColor = NSColor.systemGreen.withAlphaComponent(0.07)
    let icon = NSImageView(
      image: NSImage(systemSymbolName: "shield.lefthalf.filled", accessibilityDescription: nil)
        ?? NSImage())
    icon.contentTintColor = .systemGreen
    let title = AppTheme.label("안전하게 되돌릴 수 있습니다", size: 15, weight: .semibold)
    let detail = AppTheme.secondaryLabel(
      "원래 origin은 저장소 로컬 설정에만 보관되며 소스·커밋·브랜치는 변경하지 않습니다.", size: 12)
    let text = vertical([title, detail], spacing: 4)
    let restore = AppTheme.button("원래 연결 복원", target: self, action: #selector(restoreOrigin))
    restore.isHidden = snapshot?.routingManaged != true
    let row = NSStackView(views: [icon, text, NSView(), restore])
    row.orientation = .horizontal
    row.alignment = .centerY
    row.spacing = 12
    card.contentView = row
    return card
  }

  private func vertical(_ views: [NSView], spacing: CGFloat) -> NSStackView {
    let stack = NSStackView(views: views)
    stack.orientation = .vertical
    stack.alignment = .leading
    stack.spacing = spacing
    return stack
  }

  private func findView(identifier: String, in root: NSView) -> NSView? {
    if root.identifier?.rawValue == identifier { return root }
    for child in root.subviews {
      if let found = findView(identifier: identifier, in: child) { return found }
    }
    return nil
  }

  @objc private func revealProject() {
    if let project { model.reveal(project) }
  }

  @objc private func connectAccount() {
    guard let project,
      let popup = findView(identifier: "accountPopup", in: view) as? NSPopUpButton,
      let accountID = popup.selectedItem?.representedObject as? String,
      let account = model.accounts.first(where: { $0.id == accountID })
    else { return }

    let alert = NSAlert()
    alert.messageText = "@\(account.login)으로 연결할까요?"
    alert.informativeText = "전용 SSH 키와 호스트 별칭을 사용하도록 origin을 변경합니다. 원래 주소는 복원할 수 있습니다."
    alert.addButton(withTitle: "연결")
    alert.addButton(withTitle: "취소")
    if alert.runModal() == .alertFirstButtonReturn {
      model.connect(project, to: account)
    }
  }

  @objc private func saveOrigin() {
    guard let project,
      let field = findView(identifier: "remoteField", in: view) as? NSTextField
    else { return }
    model.setOrigin(field.stringValue, for: project)
  }

  @objc private func restoreOrigin() {
    if let project { model.restoreOriginalRemote(for: project) }
  }
}
