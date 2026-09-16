import AppKit
import GitAccountRouterCore

final class MainViewController: NSSplitViewController {
  private let model: AppModel
  private let sidebar: SidebarViewController
  private let detail: ProjectDetailViewController

  init(model: AppModel) {
    self.model = model
    sidebar = SidebarViewController(model: model)
    detail = ProjectDetailViewController(model: model)
    super.init(nibName: nil, bundle: nil)
  }

  @available(*, unavailable)
  required init?(coder: NSCoder) { nil }

  override func viewDidLoad() {
    super.viewDidLoad()
    splitView.isVertical = true
    splitView.dividerStyle = .thin

    let sidebarItem = NSSplitViewItem(sidebarWithViewController: sidebar)
    sidebarItem.minimumThickness = 260
    sidebarItem.maximumThickness = 360
    sidebarItem.canCollapse = false
    addSplitViewItem(sidebarItem)

    let detailItem = NSSplitViewItem(viewController: detail)
    detailItem.minimumThickness = 620
    addSplitViewItem(detailItem)

    model.observeChanges { [weak self] in self?.reload() }
    reload()
  }

  private func reload() {
    sidebar.reload()
    detail.show(project: model.selectedProject)
  }
}

private final class SidebarViewController: NSViewController, NSTableViewDataSource,
  NSTableViewDelegate
{
  private let model: AppModel
  private let tableView = NSTableView()
  private let accountLabel = AppTheme.secondaryLabel("")
  private let busyIndicator = NSProgressIndicator()

  init(model: AppModel) {
    self.model = model
    super.init(nibName: nil, bundle: nil)
  }

  @available(*, unavailable)
  required init?(coder: NSCoder) { nil }

  override func loadView() {
    view = NSVisualEffectView()
    (view as? NSVisualEffectView)?.material = .sidebar
    buildLayout()
  }

  func reload() {
    tableView.reloadData()
    if let id = model.selectedProjectID,
      let index = model.projects.firstIndex(where: { $0.id == id })
    {
      if tableView.selectedRow != index {
        tableView.selectRowIndexes(IndexSet(integer: index), byExtendingSelection: false)
      }
    }
    if let active = model.activeAccount {
      accountLabel.stringValue = "GitHub CLI  @\(active.login)"
    } else {
      accountLabel.stringValue = "GitHub CLI 계정 없음"
    }
    model.isBusy ? busyIndicator.startAnimation(nil) : busyIndicator.stopAnimation(nil)
  }

  private func buildLayout() {
    let icon = NSImageView(image: AppTheme.icon)
    icon.imageScaling = .scaleProportionallyUpOrDown
    icon.translatesAutoresizingMaskIntoConstraints = false
    let title = AppTheme.label("Git Account Router", size: 17, weight: .bold)
    let titleRow = NSStackView(views: [icon, title, NSView(), busyIndicator])
    titleRow.orientation = .horizontal
    titleRow.alignment = .centerY
    titleRow.spacing = 10
    icon.widthAnchor.constraint(equalToConstant: 32).isActive = true
    icon.heightAnchor.constraint(equalToConstant: 32).isActive = true
    busyIndicator.style = .spinning
    busyIndicator.controlSize = .small

    let heading = AppTheme.label("PROJECTS", size: 11, weight: .semibold)
    heading.textColor = .secondaryLabelColor

    let column = NSTableColumn(identifier: NSUserInterfaceItemIdentifier("project"))
    tableView.addTableColumn(column)
    tableView.headerView = nil
    tableView.rowHeight = 54
    tableView.intercellSpacing = NSSize(width: 0, height: 4)
    tableView.selectionHighlightStyle = .regular
    tableView.dataSource = self
    tableView.delegate = self
    tableView.backgroundColor = .clear

    let scroll = NSScrollView()
    scroll.documentView = tableView
    scroll.hasVerticalScroller = true
    scroll.drawsBackground = false

    let add = smallButton(symbol: "plus", tooltip: "프로젝트 추가", action: #selector(addProject))
    let refresh = smallButton(
      symbol: "arrow.clockwise", tooltip: "새로고침", action: #selector(refresh))
    let account = smallButton(
      symbol: "person.badge.plus", tooltip: "GitHub 계정 추가", action: #selector(addAccount))
    let status = smallButton(
      symbol: "terminal", tooltip: "상태 도구 설치", action: #selector(installStatus))
    let settings = smallButton(
      symbol: "gearshape", tooltip: "설정", action: #selector(openSettings))
    let controls = NSStackView(views: [add, refresh, NSView(), account, status, settings])
    controls.orientation = .horizontal
    controls.spacing = 6
    controls.alignment = .centerY

    let bottom = NSStackView(views: [accountLabel, controls])
    bottom.orientation = .vertical
    bottom.spacing = 10

    let stack = NSStackView(views: [titleRow, heading, scroll, bottom])
    stack.orientation = .vertical
    stack.alignment = .leading
    stack.spacing = 12
    view.addSubview(stack)
    stack.translatesAutoresizingMaskIntoConstraints = false
    scroll.translatesAutoresizingMaskIntoConstraints = false
    titleRow.translatesAutoresizingMaskIntoConstraints = false
    bottom.translatesAutoresizingMaskIntoConstraints = false

    NSLayoutConstraint.activate([
      stack.leadingAnchor.constraint(equalTo: view.leadingAnchor, constant: 16),
      stack.trailingAnchor.constraint(equalTo: view.trailingAnchor, constant: -12),
      stack.topAnchor.constraint(equalTo: view.safeAreaLayoutGuide.topAnchor, constant: 16),
      stack.bottomAnchor.constraint(equalTo: view.bottomAnchor, constant: -14),
      titleRow.widthAnchor.constraint(equalTo: stack.widthAnchor),
      scroll.widthAnchor.constraint(equalTo: stack.widthAnchor),
      scroll.heightAnchor.constraint(greaterThanOrEqualToConstant: 300),
      bottom.widthAnchor.constraint(equalTo: stack.widthAnchor),
    ])
  }

  func numberOfRows(in tableView: NSTableView) -> Int { model.projects.count }

  func tableView(_ tableView: NSTableView, viewFor tableColumn: NSTableColumn?, row: Int) -> NSView?
  {
    let project = model.projects[row]
    let snapshot = model.snapshots[project.id]
    let container = NSTableCellView()
    let icon = NSImageView(
      image: NSImage(systemSymbolName: "shippingbox.fill", accessibilityDescription: nil)
        ?? NSImage())
    icon.contentTintColor = snapshot?.connectedAccount == nil ? .secondaryLabelColor : AppTheme.cyan
    icon.translatesAutoresizingMaskIntoConstraints = false

    let title = AppTheme.label(project.displayName, size: 14, weight: .medium)
    title.lineBreakMode = .byTruncatingTail
    let account = AppTheme.secondaryLabel(
      snapshot?.connectedAccount.map { "@\($0)" } ?? "계정 확인 필요", size: 11)
    let labels = NSStackView(views: [title, account])
    labels.orientation = .vertical
    labels.alignment = .leading
    labels.spacing = 2
    let rowStack = NSStackView(views: [icon, labels, NSView()])
    rowStack.orientation = .horizontal
    rowStack.alignment = .centerY
    rowStack.spacing = 10
    container.addSubview(rowStack)
    rowStack.pinEdges(to: container, inset: 8)
    icon.widthAnchor.constraint(equalToConstant: 21).isActive = true
    return container
  }

  func tableViewSelectionDidChange(_ notification: Notification) {
    let row = tableView.selectedRow
    model.selectProject(row >= 0 && row < model.projects.count ? model.projects[row].id : nil)
  }

  private func smallButton(symbol: String, tooltip: String, action: Selector) -> NSButton {
    let button = NSButton(
      image: NSImage(systemSymbolName: symbol, accessibilityDescription: tooltip) ?? NSImage(),
      target: self, action: action)
    button.bezelStyle = .texturedRounded
    button.toolTip = tooltip
    return button
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

  @objc private func refresh() { Task { await model.refreshAll() } }
  @objc private func addAccount() { model.launchDeviceLogin() }
  @objc private func installStatus() { model.installStatusHelper() }
  @objc private func openSettings() {
    NSApp.sendAction(#selector(AppDelegate.showSettings(_:)), to: nil, from: self)
  }
}
