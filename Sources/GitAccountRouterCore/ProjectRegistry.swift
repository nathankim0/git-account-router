import Foundation

public actor ProjectRegistry {
  private let fileURL: URL
  private let fileManager: FileManager

  public init(fileURL: URL? = nil, fileManager: FileManager = .default) {
    self.fileManager = fileManager
    if let fileURL {
      self.fileURL = fileURL
    } else {
      let base = fileManager.urls(for: .applicationSupportDirectory, in: .userDomainMask)[0]
      self.fileURL =
        base
        .appendingPathComponent("GitAccountRouter", isDirectory: true)
        .appendingPathComponent("projects.json")
    }
  }

  public func load() throws -> [RegisteredProject] {
    guard fileManager.fileExists(atPath: fileURL.path) else { return [] }
    let data = try Data(contentsOf: fileURL)
    return try JSONDecoder().decode([RegisteredProject].self, from: data)
  }

  public func save(_ projects: [RegisteredProject]) throws {
    try fileManager.createDirectory(
      at: fileURL.deletingLastPathComponent(),
      withIntermediateDirectories: true
    )
    let encoder = JSONEncoder()
    encoder.outputFormatting = [.prettyPrinted, .sortedKeys]
    let data = try encoder.encode(projects)
    try data.write(to: fileURL, options: .atomic)
  }
}
