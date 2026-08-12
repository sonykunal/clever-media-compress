import UniformTypeIdentifiers
import UIKit

final class ShareViewController: UIViewController {
  private let appGroupIdentifier = "group.com.clevermedia.cleverMediaCompress"
  private let violet = UIColor(red: 0.49, green: 0.18, blue: 0.94, alpha: 1)
  private let statusLabel = UILabel()
  private let detailLabel = UILabel()
  private let activity = UIActivityIndicatorView(style: .medium)
  private let doneButton = UIButton(type: .system)

  override func viewDidLoad() {
    super.viewDidLoad()
    configureInterface()
    stageAttachments()
  }

  private func configureInterface() {
    view.backgroundColor = .systemBackground
    preferredContentSize = CGSize(width: 0, height: 330)

    let icon = UIImageView(image: UIImage(systemName: "wand.and.stars"))
    icon.tintColor = violet
    icon.contentMode = .scaleAspectFit
    icon.widthAnchor.constraint(equalToConstant: 54).isActive = true
    icon.heightAnchor.constraint(equalToConstant: 54).isActive = true

    statusLabel.text = "Preparing your media…"
    statusLabel.font = .preferredFont(forTextStyle: .title2)
    statusLabel.adjustsFontForContentSizeCategory = true
    statusLabel.textAlignment = .center
    statusLabel.numberOfLines = 2

    detailLabel.text = "Keeping the original files untouched."
    detailLabel.font = .preferredFont(forTextStyle: .body)
    detailLabel.adjustsFontForContentSizeCategory = true
    detailLabel.textColor = .secondaryLabel
    detailLabel.textAlignment = .center
    detailLabel.numberOfLines = 3

    activity.color = violet
    activity.startAnimating()

    doneButton.setTitle("Done", for: .normal)
    doneButton.setTitleColor(.white, for: .normal)
    doneButton.titleLabel?.font = .preferredFont(forTextStyle: .headline)
    doneButton.backgroundColor = violet
    doneButton.layer.cornerRadius = 16
    doneButton.isHidden = true
    doneButton.addTarget(self, action: #selector(finish), for: .touchUpInside)
    doneButton.heightAnchor.constraint(greaterThanOrEqualToConstant: 50).isActive = true

    let stack = UIStackView(arrangedSubviews: [icon, statusLabel, detailLabel, activity, doneButton])
    stack.axis = .vertical
    stack.alignment = .center
    stack.spacing = 18
    stack.translatesAutoresizingMaskIntoConstraints = false
    view.addSubview(stack)
    doneButton.widthAnchor.constraint(equalTo: stack.widthAnchor).isActive = true
    NSLayoutConstraint.activate([
      stack.leadingAnchor.constraint(equalTo: view.layoutMarginsGuide.leadingAnchor, constant: 16),
      stack.trailingAnchor.constraint(equalTo: view.layoutMarginsGuide.trailingAnchor, constant: -16),
      stack.centerYAnchor.constraint(equalTo: view.centerYAnchor),
    ])
  }

  private func stageAttachments() {
    let providers = extensionContext?.inputItems
      .compactMap { $0 as? NSExtensionItem }
      .flatMap { $0.attachments ?? [] } ?? []
    let media = providers.compactMap { provider -> (NSItemProvider, String)? in
      let identifier = provider.registeredTypeIdentifiers.first { identifier in
        guard let type = UTType(identifier) else { return false }
        return type.conforms(to: .image) || type.conforms(to: .movie)
      }
      return identifier.map { (provider, $0) }
    }
    guard !media.isEmpty else {
      showFailure("No supported photos or videos were shared.")
      return
    }
    guard let groupURL = FileManager.default.containerURL(
      forSecurityApplicationGroupIdentifier: appGroupIdentifier
    ) else {
      showFailure("The shared inbox is unavailable. Reinstall Clever Compress and try again.")
      return
    }

    let inboxURL = groupURL.appendingPathComponent("ShareInbox", isDirectory: true)
    let batchName = UUID().uuidString
    let batchURL = inboxURL.appendingPathComponent(batchName, isDirectory: true)
    do {
      try FileManager.default.createDirectory(at: batchURL, withIntermediateDirectories: true)
    } catch {
      showFailure(error.localizedDescription)
      return
    }

    let group = DispatchGroup()
    let lock = NSLock()
    var staged = Array<[String: Any]?>(repeating: nil, count: media.count)
    var firstError: Error?
    for (index, entry) in media.enumerated() {
      group.enter()
      entry.0.loadFileRepresentation(forTypeIdentifier: entry.1) { url, error in
        defer { group.leave() }
        do {
          if let error { throw error }
          guard let url else { throw ShareError.unreadableItem }
          let name = Self.mediaFilename(
            proposed: entry.0.suggestedName ?? url.lastPathComponent,
            typeIdentifier: entry.1
          )
          let destination = Self.uniqueDestination(in: batchURL, name: name)
          try FileManager.default.copyItem(at: url, to: destination)
          let mimeType = UTType(entry.1)?.preferredMIMEType ?? "application/octet-stream"
          lock.lock()
          staged[index] = [
            "relativePath": "\(batchName)/\(destination.lastPathComponent)",
            "name": name,
            "mimeType": mimeType,
          ]
          lock.unlock()
        } catch {
          lock.lock()
          firstError = firstError ?? error
          lock.unlock()
        }
      }
    }

    group.notify(queue: .global(qos: .userInitiated)) { [weak self] in
      guard let self else { return }
      if let firstError {
        try? FileManager.default.removeItem(at: batchURL)
        DispatchQueue.main.async { self.showFailure(firstError.localizedDescription) }
        return
      }
      do {
        try Self.removePreviousBatch(in: inboxURL)
        let payload: [String: Any] = [
          "batchDirectory": batchName,
          "items": staged.compactMap { $0 },
        ]
        let data = try JSONSerialization.data(withJSONObject: payload)
        try data.write(to: inboxURL.appendingPathComponent("manifest.json"), options: .atomic)
        DispatchQueue.main.async { self.showSuccess(count: media.count) }
      } catch {
        try? FileManager.default.removeItem(at: batchURL)
        DispatchQueue.main.async { self.showFailure(error.localizedDescription) }
      }
    }
  }

  private func showSuccess(count: Int) {
    activity.stopAnimating()
    activity.isHidden = true
    statusLabel.text = "Ready for compression"
    detailLabel.text = "\(count) item\(count == 1 ? " is" : "s are") ready. Open Clever Compress to choose settings and start."
    doneButton.isHidden = false
  }

  private func showFailure(_ message: String) {
    activity.stopAnimating()
    activity.isHidden = true
    statusLabel.text = "Couldn’t prepare media"
    detailLabel.text = message
    doneButton.isHidden = false
  }

  @objc private func finish() {
    extensionContext?.completeRequest(returningItems: nil)
  }

  private static func mediaFilename(proposed: String, typeIdentifier: String) -> String {
    var safe = proposed
      .replacingOccurrences(of: "/", with: "_")
      .replacingOccurrences(of: "\\", with: "_")
      .replacingOccurrences(of: "\0", with: "_")
    if (safe as NSString).pathExtension.isEmpty,
       let fileExtension = UTType(typeIdentifier)?.preferredFilenameExtension {
      safe += ".\(fileExtension)"
    }
    return safe.isEmpty ? "shared-media-\(UUID().uuidString)" : safe
  }

  private static func uniqueDestination(in directory: URL, name: String) -> URL {
    let initial = directory.appendingPathComponent(name)
    guard FileManager.default.fileExists(atPath: initial.path) else { return initial }
    let base = (name as NSString).deletingPathExtension
    let fileExtension = (name as NSString).pathExtension
    let unique = fileExtension.isEmpty
      ? "\(base)-\(UUID().uuidString)"
      : "\(base)-\(UUID().uuidString).\(fileExtension)"
    return directory.appendingPathComponent(unique)
  }

  private static func removePreviousBatch(in inboxURL: URL) throws {
    let manifestURL = inboxURL.appendingPathComponent("manifest.json")
    guard let data = try? Data(contentsOf: manifestURL),
          let manifest = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
          let previous = manifest["batchDirectory"] as? String else { return }
    let previousURL = inboxURL.appendingPathComponent(previous).standardizedFileURL
    if previousURL.path.hasPrefix(inboxURL.standardizedFileURL.path + "/") {
      try? FileManager.default.removeItem(at: previousURL)
    }
  }
}

private enum ShareError: LocalizedError {
  case unreadableItem

  var errorDescription: String? {
    "iOS did not provide a readable copy of one shared item."
  }
}
