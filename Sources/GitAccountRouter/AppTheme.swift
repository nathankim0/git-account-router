import AppKit

@MainActor
enum AppTheme {
  static let indigo = NSColor(srgbRed: 0.31, green: 0.35, blue: 0.95, alpha: 1)
  static let cyan = NSColor(srgbRed: 0.15, green: 0.78, blue: 0.86, alpha: 1)
  static let coral = NSColor(srgbRed: 0.98, green: 0.42, blue: 0.34, alpha: 1)

  static var icon: NSImage {
    if let url = Bundle.module.url(forResource: "AppIcon", withExtension: "png"),
      let image = NSImage(contentsOf: url)
    {
      return image
    }
    return NSImage(systemSymbolName: "arrow.triangle.branch", accessibilityDescription: nil)
      ?? NSImage()
  }

  static func label(_ text: String, size: CGFloat, weight: NSFont.Weight = .regular) -> NSTextField
  {
    let label = NSTextField(labelWithString: text)
    label.font = .systemFont(ofSize: size, weight: weight)
    label.maximumNumberOfLines = 0
    label.lineBreakMode = .byWordWrapping
    label.cell?.wraps = true
    label.cell?.usesSingleLineMode = false
    label.setContentCompressionResistancePriority(.defaultLow, for: .horizontal)
    return label
  }

  static func secondaryLabel(_ text: String, size: CGFloat = 13) -> NSTextField {
    let label = self.label(text, size: size)
    label.textColor = .secondaryLabelColor
    return label
  }

  static func button(_ title: String, target: AnyObject?, action: Selector?) -> NSButton {
    let button = NSButton(title: title, target: target, action: action)
    button.bezelStyle = .rounded
    button.controlSize = .large
    return button
  }

  static func card() -> NSBox {
    let box = NSBox()
    box.boxType = .custom
    box.cornerRadius = 16
    box.borderWidth = 1
    box.borderColor = .separatorColor.withAlphaComponent(0.55)
    box.fillColor = .controlBackgroundColor.withAlphaComponent(0.78)
    box.contentViewMargins = NSSize(width: 18, height: 18)
    return box
  }
}

@MainActor
extension NSView {
  func pinEdges(to other: NSView, inset: CGFloat = 0) {
    translatesAutoresizingMaskIntoConstraints = false
    NSLayoutConstraint.activate([
      leadingAnchor.constraint(equalTo: other.leadingAnchor, constant: inset),
      trailingAnchor.constraint(equalTo: other.trailingAnchor, constant: -inset),
      topAnchor.constraint(equalTo: other.topAnchor, constant: inset),
      bottomAnchor.constraint(equalTo: other.bottomAnchor, constant: -inset),
    ])
  }
}
