import Photos
import PhotosUI
import UniformTypeIdentifiers
import UIKit

final class MediaPickerCoordinator: NSObject, PHPickerViewControllerDelegate {
  typealias Completion = (Result<[[String: Any]], Error>) -> Void

  private let completion: Completion
  private var pickerController: PHPickerViewController?

  init(completion: @escaping Completion) {
    self.completion = completion
  }

  func present() throws {
    var configuration = PHPickerConfiguration(photoLibrary: .shared())
    configuration.filter = .any(of: [.images, .videos])
    configuration.selectionLimit = 100
    if #available(iOS 15.0, *) {
      configuration.selection = .ordered
    }
    let picker = PHPickerViewController(configuration: configuration)
    picker.delegate = self
    pickerController = picker
    guard let presenter = Self.topViewController() else {
      throw PickerError.noPresenter
    }
    presenter.present(picker, animated: true)
  }

  func picker(_ picker: PHPickerViewController, didFinishPicking results: [PHPickerResult]) {
    picker.dismiss(animated: true)
    guard !results.isEmpty else {
      completion(.success([]))
      return
    }

    let group = DispatchGroup()
    let lock = NSLock()
    var imported = Array<[String: Any]?>(repeating: nil, count: results.count)
    var firstError: Error?

    for (index, result) in results.enumerated() {
      group.enter()
      importResult(result) { result in
        lock.lock()
        switch result {
        case .success(let payload): imported[index] = payload
        case .failure(let error): firstError = firstError ?? error
        }
        lock.unlock()
        group.leave()
      }
    }

    group.notify(queue: .main) { [completion] in
      if let firstError {
        completion(.failure(firstError))
      } else {
        completion(.success(imported.compactMap { $0 }))
      }
    }
  }

  private func importResult(
    _ result: PHPickerResult,
    completion: @escaping (Result<[String: Any], Error>) -> Void
  ) {
    let provider = result.itemProvider
    let typeIdentifier = provider.registeredTypeIdentifiers.first { identifier in
      guard let type = UTType(identifier) else { return false }
      return type.conforms(to: .image) || type.conforms(to: .movie)
    }
    guard let typeIdentifier else {
      completion(.failure(PickerError.unsupportedMedia))
      return
    }

    provider.loadFileRepresentation(forTypeIdentifier: typeIdentifier) { url, error in
      if let error {
        completion(.failure(error))
        return
      }
      guard let url else {
        completion(.failure(PickerError.unreadableMedia))
        return
      }

      do {
        let asset = result.assetIdentifier.flatMap { identifier in
          PHAsset.fetchAssets(withLocalIdentifiers: [identifier], options: nil).firstObject
        }
        let resource = asset.flatMap { PHAssetResource.assetResources(for: $0).first }
        let proposedName = resource?.originalFilename
          ?? provider.suggestedName
          ?? url.lastPathComponent
        let safeName = Self.safeFilename(proposedName, typeIdentifier: typeIdentifier)
        let directory = FileManager.default.temporaryDirectory
          .appendingPathComponent("picked-media", isDirectory: true)
          .appendingPathComponent(UUID().uuidString, isDirectory: true)
        try FileManager.default.createDirectory(
          at: directory,
          withIntermediateDirectories: true
        )
        let destination = directory.appendingPathComponent(safeName)
        try FileManager.default.copyItem(at: url, to: destination)
        let values = try destination.resourceValues(forKeys: [.fileSizeKey])
        let type = UTType(typeIdentifier)
        let albums = asset.map(Self.userAlbumIdentifiers) ?? []
        var payload: [String: Any] = [
          "path": destination.path,
          "name": safeName,
          "mimeType": type?.preferredMIMEType ?? "application/octet-stream",
          "byteSize": values.fileSize ?? 0,
          "sourceAlbumIdentifiers": albums,
          "supportsRecoverableReclaim": true,
        ]
        if let identifier = result.assetIdentifier {
          payload["sourceAssetIdentifier"] = identifier
        }
        if let date = asset?.creationDate {
          payload["sourceCaptureMillis"] = Int64(date.timeIntervalSince1970 * 1_000)
        }
        completion(.success(payload))
      } catch {
        completion(.failure(error))
      }
    }
  }

  private static func safeFilename(_ proposed: String, typeIdentifier: String) -> String {
    let clean = proposed
      .replacingOccurrences(of: "/", with: "_")
      .replacingOccurrences(of: "\\", with: "_")
      .replacingOccurrences(of: "\0", with: "_")
    if !(clean as NSString).pathExtension.isEmpty { return clean }
    let fileExtension = UTType(typeIdentifier)?.preferredFilenameExtension ?? "bin"
    return "shared-media-\(UUID().uuidString).\(fileExtension)"
  }

  private static func userAlbumIdentifiers(_ asset: PHAsset) -> [String] {
    let collections = PHAssetCollection.fetchAssetCollectionsContaining(
      asset,
      with: .album,
      options: nil
    )
    var identifiers: [String] = []
    collections.enumerateObjects { collection, _, _ in
      identifiers.append(collection.localIdentifier)
    }
    return identifiers
  }

  private static func topViewController() -> UIViewController? {
    let scenes = UIApplication.shared.connectedScenes.compactMap { $0 as? UIWindowScene }
    let root = scenes.flatMap(\.windows).first(where: \.isKeyWindow)?.rootViewController
    var current = root
    while let presented = current?.presentedViewController { current = presented }
    if let navigation = current as? UINavigationController {
      return navigation.visibleViewController ?? navigation
    }
    if let tabs = current as? UITabBarController {
      return tabs.selectedViewController ?? tabs
    }
    return current
  }
}

private enum PickerError: LocalizedError {
  case noPresenter
  case unsupportedMedia
  case unreadableMedia

  var errorDescription: String? {
    switch self {
    case .noPresenter: return "iOS could not present the photo picker."
    case .unsupportedMedia: return "The selected item is not a supported photo or video."
    case .unreadableMedia: return "iOS could not read the selected media."
    }
  }
}
