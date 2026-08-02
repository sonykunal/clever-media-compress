import Flutter
import CoreLocation
import ImageIO
import Photos
import UniformTypeIdentifiers
import UIKit

@main
@objc class AppDelegate: FlutterAppDelegate, FlutterImplicitEngineDelegate {
  override func application(
    _ application: UIApplication,
    didFinishLaunchingWithOptions launchOptions: [UIApplication.LaunchOptionsKey: Any]?
  ) -> Bool {
    return super.application(application, didFinishLaunchingWithOptions: launchOptions)
  }

  func didInitializeImplicitFlutterEngine(_ engineBridge: FlutterImplicitEngineBridge) {
    GeneratedPluginRegistrant.register(with: engineBridge.pluginRegistry)
    ChronologyMediaEngine.register(
      messenger: engineBridge.applicationRegistrar.messenger()
    )
  }
}

private final class ChronologyMediaEngine {
  private static let channelName = "clever_media_compress/media"
  private static let queue = DispatchQueue(
    label: "com.clevermedia.compress.engine",
    qos: .userInitiated
  )

  static func register(messenger: FlutterBinaryMessenger) {
    let channel = FlutterMethodChannel(
      name: channelName,
      binaryMessenger: messenger
    )
    channel.setMethodCallHandler { call, result in
      guard call.method == "compressAndPublish" else {
        result(FlutterMethodNotImplemented)
        return
      }

      queue.async {
        do {
          let payload = try compressAndPublish(arguments: call.arguments)
          DispatchQueue.main.async { result(payload) }
        } catch {
          DispatchQueue.main.async {
            result(
              FlutterError(
                code: "compression_failed",
                message: error.localizedDescription,
                details: nil
              )
            )
          }
        }
      }
    }
  }

  private static func compressAndPublish(arguments: Any?) throws -> [String: Any] {
    guard let values = arguments as? [String: Any] else {
      throw EngineError.invalidArguments
    }
    guard string(values, "mediaKind") == "image" else {
      return failure(
        "Video compression will be added through AVAssetExportSession in the next engine milestone."
      )
    }

    let sourcePath = try requiredString(values, "sourcePath")
    let sourceName = try requiredString(values, "sourceName")
    let suffix = string(values, "outputSuffix") ?? "_compressed"
    let quality = min(max(number(values, "quality")?.doubleValue ?? 72, 20), 95) / 100
    let scale = min(max(number(values, "resolutionScale")?.doubleValue ?? 1, 0.25), 1)
    let preserveMetadata = bool(values, "preserveMetadata", fallback: true)
    let preserveLocation = bool(values, "preserveLocation", fallback: true)
    let sourceURL = URL(fileURLWithPath: sourcePath)

    guard let imageSource = CGImageSourceCreateWithURL(sourceURL as CFURL, nil),
          CGImageSourceGetCount(imageSource) > 0,
          let sourceProperties = CGImageSourceCopyPropertiesAtIndex(
            imageSource,
            0,
            nil
          ) as? [CFString: Any]
    else {
      throw EngineError.unsupportedImage
    }

    let fingerprint = captureFingerprint(sourceProperties)
    let captureDate = captureDate(sourceProperties)
    let location = preserveLocation ? location(sourceProperties) : nil
    let width = (sourceProperties[kCGImagePropertyPixelWidth] as? NSNumber)?.doubleValue ?? 1
    let height = (sourceProperties[kCGImagePropertyPixelHeight] as? NSNumber)?.doubleValue ?? 1
    let maxPixelSize = max(1, Int(max(width, height) * scale))
    let thumbnailOptions: [CFString: Any] = [
      kCGImageSourceCreateThumbnailFromImageAlways: true,
      kCGImageSourceCreateThumbnailWithTransform: true,
      kCGImageSourceThumbnailMaxPixelSize: maxPixelSize,
      kCGImageSourceShouldCacheImmediately: false,
    ]
    guard let image = CGImageSourceCreateThumbnailAtIndex(
      imageSource,
      0,
      thumbnailOptions as CFDictionary
    ) else {
      throw EngineError.decodeFailed
    }

    let baseName = (sourceName as NSString).deletingPathExtension
    let outputName = "\(baseName)\(suffix).jpg"
    let outputURL = FileManager.default.temporaryDirectory
      .appendingPathComponent(UUID().uuidString)
      .appendingPathExtension("jpg")

    guard let destination = CGImageDestinationCreateWithURL(
      outputURL as CFURL,
      UTType.jpeg.identifier as CFString,
      1,
      nil
    ) else {
      throw EngineError.encodeFailed
    }

    var outputProperties: [CFString: Any] = [
      kCGImageDestinationLossyCompressionQuality: quality,
      kCGImagePropertyOrientation: 1,
      kCGImagePropertyPixelWidth: image.width,
      kCGImagePropertyPixelHeight: image.height,
    ]
    if preserveMetadata {
      outputProperties.merge(sourceProperties) { current, _ in current }
      outputProperties[kCGImageDestinationLossyCompressionQuality] = quality
      outputProperties[kCGImagePropertyOrientation] = 1
      outputProperties[kCGImagePropertyPixelWidth] = image.width
      outputProperties[kCGImagePropertyPixelHeight] = image.height
      if !preserveLocation {
        outputProperties.removeValue(forKey: kCGImagePropertyGPSDictionary)
      }
    }

    CGImageDestinationAddImage(destination, image, outputProperties as CFDictionary)
    guard CGImageDestinationFinalize(destination) else {
      throw EngineError.encodeFailed
    }
    defer { try? FileManager.default.removeItem(at: outputURL) }

    let verified = preserveMetadata && fingerprint != nil &&
      fingerprint == outputFingerprint(outputURL)
    let localIdentifier = try publishPhoto(
      fileURL: outputURL,
      outputName: outputName,
      creationDate: captureDate,
      location: location
    )
    let bytes = (try? outputURL.resourceValues(forKeys: [.fileSizeKey]).fileSize) ?? 0

    return [
      "success": true,
      "outputUri": "ph://\(localIdentifier)",
      "outputName": outputName,
      "outputBytes": bytes,
      "captureDateVerified": verified,
      "message": verified
        ? "Capture date verified and saved to Photos."
        : "Saved to Photos, but no source EXIF capture date was available to verify.",
    ]
  }

  private static func publishPhoto(
    fileURL: URL,
    outputName: String,
    creationDate: Date?,
    location: CLLocation?
  ) throws -> String {
    let authorization = photoAuthorization()
    guard authorization == .authorized || authorization == .limited else {
      throw EngineError.photoAccessDenied
    }

    let semaphore = DispatchSemaphore(value: 0)
    var identifier: String?
    var publishError: Error?
    PHPhotoLibrary.shared().performChanges {
      let request = PHAssetCreationRequest.forAsset()
      request.creationDate = creationDate
      request.location = location
      let options = PHAssetResourceCreationOptions()
      options.originalFilename = outputName
      request.addResource(with: .photo, fileURL: fileURL, options: options)
      identifier = request.placeholderForCreatedAsset?.localIdentifier
    } completionHandler: { success, error in
      if !success { publishError = error ?? EngineError.photoPublishFailed }
      semaphore.signal()
    }
    semaphore.wait()

    if let publishError { throw publishError }
    guard let identifier else { throw EngineError.photoPublishFailed }
    return identifier
  }

  private static func photoAuthorization() -> PHAuthorizationStatus {
    let current = PHPhotoLibrary.authorizationStatus(for: .readWrite)
    guard current == .notDetermined else { return current }
    let semaphore = DispatchSemaphore(value: 0)
    var resolved = current
    PHPhotoLibrary.requestAuthorization(for: .readWrite) { status in
      resolved = status
      semaphore.signal()
    }
    semaphore.wait()
    return resolved
  }

  private static func captureFingerprint(_ properties: [CFString: Any]) -> String? {
    let exif = properties[kCGImagePropertyExifDictionary] as? [CFString: Any]
    let tiff = properties[kCGImagePropertyTIFFDictionary] as? [CFString: Any]
    guard let date = exif?[kCGImagePropertyExifDateTimeOriginal] as? String
      ?? tiff?[kCGImagePropertyTIFFDateTime] as? String
    else { return nil }
    let subsecond = exif?[kCGImagePropertyExifSubsecTimeOriginal] as? String ?? ""
    let offset = exif?["OffsetTimeOriginal" as CFString] as? String ?? ""
    return "\(date)|\(subsecond)|\(offset)"
  }

  private static func outputFingerprint(_ url: URL) -> String? {
    guard let source = CGImageSourceCreateWithURL(url as CFURL, nil),
          let properties = CGImageSourceCopyPropertiesAtIndex(source, 0, nil)
            as? [CFString: Any]
    else { return nil }
    return captureFingerprint(properties)
  }

  private static func captureDate(_ properties: [CFString: Any]) -> Date? {
    let exif = properties[kCGImagePropertyExifDictionary] as? [CFString: Any]
    let tiff = properties[kCGImagePropertyTIFFDictionary] as? [CFString: Any]
    guard let value = exif?[kCGImagePropertyExifDateTimeOriginal] as? String
      ?? tiff?[kCGImagePropertyTIFFDateTime] as? String
    else { return nil }

    let formatter = DateFormatter()
    formatter.locale = Locale(identifier: "en_US_POSIX")
    formatter.dateFormat = "yyyy:MM:dd HH:mm:ss"
    if let offset = exif?["OffsetTimeOriginal" as CFString] as? String {
      formatter.timeZone = timeZone(offset)
    } else {
      formatter.timeZone = .current
    }
    return formatter.date(from: value)
  }

  private static func timeZone(_ exifOffset: String) -> TimeZone {
    let sign = exifOffset.hasPrefix("-") ? -1 : 1
    let numbers = exifOffset.dropFirst().split(separator: ":").compactMap { Int($0) }
    guard numbers.count == 2 else { return .current }
    return TimeZone(secondsFromGMT: sign * (numbers[0] * 3600 + numbers[1] * 60)) ?? .current
  }

  private static func location(_ properties: [CFString: Any]) -> CLLocation? {
    guard let gps = properties[kCGImagePropertyGPSDictionary] as? [CFString: Any],
          let latitude = (gps[kCGImagePropertyGPSLatitude] as? NSNumber)?.doubleValue,
          let longitude = (gps[kCGImagePropertyGPSLongitude] as? NSNumber)?.doubleValue
    else { return nil }
    let latitudeRef = gps[kCGImagePropertyGPSLatitudeRef] as? String
    let longitudeRef = gps[kCGImagePropertyGPSLongitudeRef] as? String
    let signedLatitude = latitudeRef == "S" ? -latitude : latitude
    let signedLongitude = longitudeRef == "W" ? -longitude : longitude
    return CLLocation(latitude: signedLatitude, longitude: signedLongitude)
  }

  private static func string(_ values: [String: Any], _ key: String) -> String? {
    values[key] as? String
  }

  private static func number(_ values: [String: Any], _ key: String) -> NSNumber? {
    values[key] as? NSNumber
  }

  private static func bool(
    _ values: [String: Any],
    _ key: String,
    fallback: Bool
  ) -> Bool {
    (values[key] as? NSNumber)?.boolValue ?? fallback
  }

  private static func requiredString(
    _ values: [String: Any],
    _ key: String
  ) throws -> String {
    guard let value = string(values, key), !value.isEmpty else {
      throw EngineError.invalidArguments
    }
    return value
  }

  private static func failure(_ message: String) -> [String: Any] {
    [
      "success": false,
      "captureDateVerified": false,
      "message": message,
    ]
  }
}

private enum EngineError: LocalizedError {
  case invalidArguments
  case unsupportedImage
  case decodeFailed
  case encodeFailed
  case photoAccessDenied
  case photoPublishFailed

  var errorDescription: String? {
    switch self {
    case .invalidArguments:
      return "The app sent incomplete compression settings."
    case .unsupportedImage:
      return "iOS cannot read this image or its metadata."
    case .decodeFailed:
      return "iOS could not decode the selected image."
    case .encodeFailed:
      return "iOS could not create the compressed JPEG."
    case .photoAccessDenied:
      return "Photo Library access is required to save the compressed copy."
    case .photoPublishFailed:
      return "Photos could not publish the compressed copy."
    }
  }
}
