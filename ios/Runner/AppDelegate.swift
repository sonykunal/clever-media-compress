import Flutter
import AVFoundation
import CoreMedia
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
      switch call.method {
      case "requestMediaLibraryAccess":
        requestMediaLibraryAccess(result: result)
      case "openAppSettings":
        openAppSettings(result: result)
      case "compressAndPublish":
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
      default:
        result(FlutterMethodNotImplemented)
      }
    }
  }

  private static func requestMediaLibraryAccess(result: @escaping FlutterResult) {
    let current = PHPhotoLibrary.authorizationStatus(for: .readWrite)
    guard current == .notDetermined else {
      result(photoAccessPayload(current))
      return
    }
    PHPhotoLibrary.requestAuthorization(for: .readWrite) { status in
      DispatchQueue.main.async {
        result(photoAccessPayload(status))
      }
    }
  }

  private static func openAppSettings(result: FlutterResult) {
    guard let url = URL(string: UIApplication.openSettingsURLString) else {
      result(nil)
      return
    }
    UIApplication.shared.open(url)
    result(nil)
  }

  private static func photoAccessPayload(_ status: PHAuthorizationStatus) -> [String: Any] {
    let normalized: String
    let message: String
    switch status {
    case .authorized:
      normalized = "full"
      message = "Full Photos access is enabled."
    case .limited:
      normalized = "limited"
      message = "iOS is allowing Limited Photos access. Allow Full Access for the most reliable save and date verification flow."
    case .denied, .restricted:
      normalized = "denied"
      message = "Photos access is needed to save compressed copies and verify capture dates."
    case .notDetermined:
      normalized = "denied"
      message = "Photos access is needed to save compressed copies and verify capture dates."
    @unknown default:
      normalized = "unavailable"
      message = "Photos permission is unavailable on this iOS version."
    }
    return [
      "status": normalized,
      "message": message,
      "canOpenSettings": normalized != "full",
    ]
  }

  private static func compressAndPublish(arguments: Any?) throws -> [String: Any] {
    guard let values = arguments as? [String: Any] else {
      throw EngineError.invalidArguments
    }
    let mediaKind = string(values, "mediaKind") ?? "image"
    if mediaKind == "video" {
      return try compressVideoAndPublish(values: values)
    }
    guard mediaKind == "image" else {
      return failure("Unsupported media category: \(mediaKind)")
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

    let sourceCaptureStamp = captureStamp(sourceProperties)
    let fingerprint = sourceCaptureStamp?.fingerprint
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

    let format = ImageOutputFormat(sourceName: sourceName)
    let baseName = (sourceName as NSString).deletingPathExtension
    let outputName = "\(baseName)\(suffix).\(format.extension)"
    let outputURL = FileManager.default.temporaryDirectory
      .appendingPathComponent(UUID().uuidString)
      .appendingPathExtension(format.extension)

    guard let destination = CGImageDestinationCreateWithURL(
      outputURL as CFURL,
      format.typeIdentifier as CFString,
      1,
      nil
    ) else {
      throw EngineError.encodeFailed
    }

    var outputProperties: [CFString: Any] = [
      kCGImagePropertyOrientation: 1,
      kCGImagePropertyPixelWidth: image.width,
      kCGImagePropertyPixelHeight: image.height,
    ]
    if format.isLossy {
      outputProperties[kCGImageDestinationLossyCompressionQuality] = quality
    }
    if preserveMetadata {
      outputProperties.merge(sourceProperties) { current, _ in current }
      if format.isLossy {
        outputProperties[kCGImageDestinationLossyCompressionQuality] = quality
      } else {
        outputProperties.removeValue(forKey: kCGImageDestinationLossyCompressionQuality)
      }
      outputProperties[kCGImagePropertyOrientation] = 1
      outputProperties[kCGImagePropertyPixelWidth] = image.width
      outputProperties[kCGImagePropertyPixelHeight] = image.height
      if let sourceCaptureStamp {
        var exif = outputProperties[kCGImagePropertyExifDictionary]
          as? [CFString: Any] ?? [:]
        exif[kCGImagePropertyExifDateTimeOriginal] = sourceCaptureStamp.date
        if !sourceCaptureStamp.subsecond.isEmpty {
          exif[kCGImagePropertyExifSubsecTimeOriginal] = sourceCaptureStamp.subsecond
        }
        if !sourceCaptureStamp.offset.isEmpty {
          exif["OffsetTimeOriginal" as CFString] = sourceCaptureStamp.offset
        }
        outputProperties[kCGImagePropertyExifDictionary] = exif
      }
      if !preserveLocation {
        outputProperties.removeValue(forKey: kCGImagePropertyGPSDictionary)
      }
    }

    CGImageDestinationAddImage(destination, image, outputProperties as CFDictionary)
    guard CGImageDestinationFinalize(destination) else {
      throw EngineError.encodeFailed
    }
    defer { try? FileManager.default.removeItem(at: outputURL) }

    let embeddedDateVerified = preserveMetadata && fingerprint != nil &&
      fingerprint == outputFingerprint(outputURL)
    let localIdentifier = try publishAsset(
      fileURL: outputURL,
      outputName: outputName,
      creationDate: captureDate,
      location: location,
      resourceType: .photo
    )
    let galleryDateVerified = captureDate.map {
      verifyPublishedCreationDate(localIdentifier, expected: $0)
    } ?? false
    let verified = embeddedDateVerified && galleryDateVerified
    let bytes = (try? outputURL.resourceValues(forKeys: [.fileSizeKey]).fileSize) ?? 0

    return [
      "success": true,
      "outputUri": "ph://\(localIdentifier)",
      "outputName": outputName,
      "outputBytes": bytes,
      "captureDateVerified": verified,
      "message": verificationMessage(
        sourceHasCaptureDate: sourceCaptureStamp != nil,
        embeddedDateVerified: embeddedDateVerified,
        galleryDateVerified: galleryDateVerified
      ),
    ]
  }

  private static func compressVideoAndPublish(values: [String: Any]) throws -> [String: Any] {
    let sourcePath = try requiredString(values, "sourcePath")
    let sourceName = try requiredString(values, "sourceName")
    let suffix = string(values, "outputSuffix") ?? "_compressed"
    let quality = min(max(number(values, "quality")?.doubleValue ?? 72, 20), 95)
    let scale = min(max(number(values, "resolutionScale")?.doubleValue ?? 1, 0.25), 1)
    let preserveMetadata = bool(values, "preserveMetadata", fallback: true)
    let preserveLocation = bool(values, "preserveLocation", fallback: true)
    let sourceURL = URL(fileURLWithPath: sourcePath)
    let asset = AVURLAsset(url: sourceURL)
    let galleryCaptureDate = number(values, "sourceCaptureMillis").map {
      Date(timeIntervalSince1970: $0.doubleValue / 1_000)
    }
    let captureDate = galleryCaptureDate
      ?? videoCaptureDate(asset: asset)
      ?? captureDateFromFileName(sourceName)
    let location = preserveLocation ? videoLocation(asset: asset) : nil
    let compatiblePresets = AVAssetExportSession.exportPresets(compatibleWith: asset)
    let requestedPreset = videoPreset(quality: quality, scale: scale)
    let preset = compatiblePresets.contains(requestedPreset)
      ? requestedPreset
      : compatiblePresets.contains(AVAssetExportPresetMediumQuality)
        ? AVAssetExportPresetMediumQuality
        : AVAssetExportPresetPassthrough

    guard let exportSession = AVAssetExportSession(asset: asset, presetName: preset) else {
      throw EngineError.unsupportedVideo
    }
    let outputType: AVFileType = exportSession.supportedFileTypes.contains(.mp4) ? .mp4 : .mov
    let outputExtension = outputType == .mp4 ? "mp4" : "mov"
    let baseName = (sourceName as NSString).deletingPathExtension
    let outputName = "\(baseName)\(suffix).\(outputExtension)"
    let outputURL = FileManager.default.temporaryDirectory
      .appendingPathComponent(UUID().uuidString)
      .appendingPathExtension(outputExtension)
    defer { try? FileManager.default.removeItem(at: outputURL) }

    exportSession.outputURL = outputURL
    exportSession.outputFileType = outputType
    exportSession.shouldOptimizeForNetworkUse = true
    if preserveMetadata {
      exportSession.metadata = videoOutputMetadata(
        asset: asset,
        captureDate: captureDate,
        preserveLocation: preserveLocation
      )
    } else {
      exportSession.metadata = []
    }

    let semaphore = DispatchSemaphore(value: 0)
    exportSession.exportAsynchronously { semaphore.signal() }
    semaphore.wait()
    switch exportSession.status {
    case .completed:
      break
    case .failed, .cancelled:
      throw exportSession.error ?? EngineError.videoExportFailed
    default:
      throw EngineError.videoExportFailed
    }

    let embeddedDateVerified = preserveMetadata && captureDate.map { expected in
      videoCaptureDate(asset: AVURLAsset(url: outputURL)).map {
        abs($0.timeIntervalSince(expected)) < 1
      } ?? false
    } ?? false

    let localIdentifier = try publishAsset(
      fileURL: outputURL,
      outputName: outputName,
      creationDate: captureDate,
      location: location,
      resourceType: .video
    )
    let galleryDateVerified = captureDate.map {
      verifyPublishedCreationDate(localIdentifier, expected: $0)
    } ?? false
    let verified = embeddedDateVerified && galleryDateVerified
    let bytes = (try? outputURL.resourceValues(forKeys: [.fileSizeKey]).fileSize) ?? 0
    return [
      "success": true,
      "outputUri": "ph://\(localIdentifier)",
      "outputName": outputName,
      "outputBytes": bytes,
      "captureDateVerified": verified,
      "message": verified
        ? "Video capture date verified in the exported file and Apple Photos."
        : captureDate == nil
          ? "Video saved, but no source capture date was available to verify."
          : !embeddedDateVerified
            ? "Video saved, but iOS could not verify the exported capture timestamp."
            : "Video saved, but Apple Photos did not report the expected capture date.",
    ]
  }

  private static func videoPreset(quality: Double, scale: Double) -> String {
    if scale <= 0.35 { return AVAssetExportPreset640x480 }
    if scale <= 0.6 { return AVAssetExportPreset960x540 }
    if scale <= 0.82 { return AVAssetExportPreset1280x720 }
    if quality < 50 { return AVAssetExportPresetLowQuality }
    if quality < 82 { return AVAssetExportPresetMediumQuality }
    return AVAssetExportPresetHighestQuality
  }

  private static func videoCaptureDate(asset: AVAsset) -> Date? {
    if let date = asset.creationDate?.dateValue { return date }
    if let value = asset.creationDate?.stringValue {
      if let date = iso8601Date(value) { return date }
    }
    let identifiers: [AVMetadataIdentifier] = [
      .commonIdentifierCreationDate,
      .quickTimeMetadataCreationDate,
    ]
    for identifier in identifiers {
      let items = AVMetadataItem.metadataItems(
        from: asset.metadata,
        filteredByIdentifier: identifier
      )
      if let date = items.first?.dateValue { return date }
      if let value = items.first?.stringValue,
         let date = iso8601Date(value) { return date }
    }
    return nil
  }

  private static func videoOutputMetadata(
    asset: AVAsset,
    captureDate: Date?,
    preserveLocation: Bool
  ) -> [AVMetadataItem] {
    var output = asset.metadata.filter { item in
      guard let identifier = item.identifier else { return true }
      let isCreationDate = identifier == .commonIdentifierCreationDate ||
        identifier == .quickTimeMetadataCreationDate
      let isLocation = identifier == .quickTimeMetadataLocationISO6709
      return !isCreationDate && (preserveLocation || !isLocation)
    }

    if let captureDate {
      output.append(
        metadataItem(
          identifier: .commonIdentifierCreationDate,
          value: iso8601String(captureDate)
        )
      )
      output.append(
        metadataItem(
          identifier: .quickTimeMetadataCreationDate,
          value: iso8601String(captureDate)
        )
      )
    }

    return output
  }

  private static func metadataItem(
    identifier: AVMetadataIdentifier,
    value: String
  ) -> AVMetadataItem {
    let item = AVMutableMetadataItem()
    item.identifier = identifier
    item.value = value as NSString
    item.dataType = kCMMetadataBaseDataType_UTF8 as String
    return item
  }

  private static func captureDateFromFileName(_ name: String) -> Date? {
    guard let expression = try? NSRegularExpression(
      pattern: #"(\d{8})[_-](\d{6})"#
    ) else { return nil }
    let range = NSRange(name.startIndex..., in: name)
    guard let match = expression.firstMatch(in: name, range: range),
          let dayRange = Range(match.range(at: 1), in: name),
          let timeRange = Range(match.range(at: 2), in: name) else {
      return nil
    }
    let formatter = DateFormatter()
    formatter.locale = Locale(identifier: "en_US_POSIX")
    formatter.timeZone = .current
    formatter.dateFormat = "yyyyMMddHHmmss"
    return formatter.date(from: "\(name[dayRange])\(name[timeRange])")
  }

  private static func iso8601String(_ date: Date) -> String {
    let formatter = ISO8601DateFormatter()
    formatter.formatOptions = [.withInternetDateTime, .withFractionalSeconds]
    return formatter.string(from: date)
  }

  private static func iso8601Date(_ value: String) -> Date? {
    let formatter = ISO8601DateFormatter()
    if let date = formatter.date(from: value) { return date }
    formatter.formatOptions = [.withInternetDateTime, .withFractionalSeconds]
    return formatter.date(from: value)
  }

  private static func videoLocation(asset: AVAsset) -> CLLocation? {
    let items = AVMetadataItem.metadataItems(
      from: asset.metadata,
      filteredByIdentifier: .quickTimeMetadataLocationISO6709
    )
    guard let value = items.first?.stringValue else { return nil }
    let pattern = #"^([+-]\d+(?:\.\d+)?)([+-]\d+(?:\.\d+)?)"#
    guard let expression = try? NSRegularExpression(pattern: pattern),
          let match = expression.firstMatch(
            in: value,
            range: NSRange(value.startIndex..., in: value)
          ),
          let latitudeRange = Range(match.range(at: 1), in: value),
          let longitudeRange = Range(match.range(at: 2), in: value),
          let latitude = Double(value[latitudeRange]),
          let longitude = Double(value[longitudeRange]) else { return nil }
    return CLLocation(latitude: latitude, longitude: longitude)
  }

  private static func publishAsset(
    fileURL: URL,
    outputName: String,
    creationDate: Date?,
    location: CLLocation?,
    resourceType: PHAssetResourceType
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
      request.addResource(with: resourceType, fileURL: fileURL, options: options)
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

  private static func verifyPublishedCreationDate(
    _ localIdentifier: String,
    expected: Date
  ) -> Bool {
    guard let creationDate = PHAsset.fetchAssets(
      withLocalIdentifiers: [localIdentifier],
      options: nil
    ).firstObject?.creationDate else { return false }
    return abs(creationDate.timeIntervalSince(expected)) < 1
  }

  private static func verificationMessage(
    sourceHasCaptureDate: Bool,
    embeddedDateVerified: Bool,
    galleryDateVerified: Bool
  ) -> String {
    if embeddedDateVerified && galleryDateVerified {
      return "Capture date verified in the file and Apple Photos."
    }
    if !sourceHasCaptureDate {
      return "Saved to Photos, but the source had no embedded capture date to preserve."
    }
    if !embeddedDateVerified {
      return "Saved to Photos, but iOS could not verify the embedded capture date."
    }
    return "Saved to Photos, but Apple Photos did not report the expected capture date."
  }

  private static func captureStamp(_ properties: [CFString: Any]) -> CaptureStamp? {
    let exif = properties[kCGImagePropertyExifDictionary] as? [CFString: Any]
    let tiff = properties[kCGImagePropertyTIFFDictionary] as? [CFString: Any]
    let original = exif?[kCGImagePropertyExifDateTimeOriginal] as? String
    let digitized = exif?[kCGImagePropertyExifDateTimeDigitized] as? String
    guard let date = original ?? digitized
      ?? tiff?[kCGImagePropertyTIFFDateTime] as? String else { return nil }
    let subsecond = original != nil
      ? exif?[kCGImagePropertyExifSubsecTimeOriginal] as? String ?? ""
      : digitized != nil
        ? exif?["SubsecTimeDigitized" as CFString] as? String ?? ""
        : exif?["SubsecTime" as CFString] as? String ?? ""
    let offset = original != nil
      ? exif?["OffsetTimeOriginal" as CFString] as? String ?? ""
      : digitized != nil
        ? exif?["OffsetTimeDigitized" as CFString] as? String ?? ""
        : exif?["OffsetTime" as CFString] as? String ?? ""
    return CaptureStamp(date: date, subsecond: subsecond, offset: offset)
  }

  private static func outputFingerprint(_ url: URL) -> String? {
    guard let source = CGImageSourceCreateWithURL(url as CFURL, nil),
          let properties = CGImageSourceCopyPropertiesAtIndex(source, 0, nil)
            as? [CFString: Any]
    else { return nil }
    return captureStamp(properties)?.fingerprint
  }

  private static func captureDate(_ properties: [CFString: Any]) -> Date? {
    guard let stamp = captureStamp(properties) else { return nil }

    let formatter = DateFormatter()
    formatter.locale = Locale(identifier: "en_US_POSIX")
    formatter.dateFormat = "yyyy:MM:dd HH:mm:ss"
    if !stamp.offset.isEmpty {
      formatter.timeZone = timeZone(stamp.offset)
    } else {
      formatter.timeZone = .current
    }
    guard let date = formatter.date(from: stamp.date) else { return nil }
    let subsecondDigits = String(stamp.subsecond.filter(\.isNumber).prefix(3))
    let normalizedSubseconds = subsecondDigits.padding(
      toLength: 3,
      withPad: "0",
      startingAt: 0
    )
    let milliseconds = Double(normalizedSubseconds) ?? 0
    return date.addingTimeInterval(milliseconds / 1_000)
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
  case unsupportedVideo
  case decodeFailed
  case encodeFailed
  case photoAccessDenied
  case photoPublishFailed
  case videoExportFailed

  var errorDescription: String? {
    switch self {
    case .invalidArguments:
      return "The app sent incomplete compression settings."
    case .unsupportedImage:
      return "iOS cannot read this image or its metadata."
    case .unsupportedVideo:
      return "This video's container or codec is not supported by this iPhone."
    case .decodeFailed:
      return "iOS could not decode the selected image."
    case .encodeFailed:
      return "iOS could not create the compressed image."
    case .photoAccessDenied:
      return "Photo Library access is required to save the compressed copy."
    case .photoPublishFailed:
      return "Photos could not publish the compressed copy."
    case .videoExportFailed:
      return "iOS could not transcode this video with an available export preset."
    }
  }
}

private struct CaptureStamp {
  let date: String
  let subsecond: String
  let offset: String

  var fingerprint: String { "\(date)|\(subsecond)|\(offset)" }
}

private struct ImageOutputFormat {
  let `extension`: String
  let typeIdentifier: String
  let isLossy: Bool

  init(sourceName: String) {
    let sourceExtension = (sourceName as NSString).pathExtension
    let destinationTypes = CGImageDestinationCopyTypeIdentifiers() as? [String] ?? []
    switch sourceExtension.lowercased() {
    case "png":
      self.extension = sourceExtension
      typeIdentifier = UTType.png.identifier
      isLossy = false
    case "jpeg":
      self.extension = sourceExtension
      typeIdentifier = UTType.jpeg.identifier
      isLossy = true
    case "heic", "heif" where destinationTypes.contains(UTType.heic.identifier):
      self.extension = sourceExtension
      typeIdentifier = UTType.heic.identifier
      isLossy = true
    case "webp" where destinationTypes.contains(UTType.webP.identifier):
      self.extension = sourceExtension
      typeIdentifier = UTType.webP.identifier
      isLossy = true
    default:
      self.extension = sourceExtension.lowercased() == "jpg" ? sourceExtension : "jpg"
      typeIdentifier = UTType.jpeg.identifier
      isLossy = true
    }
  }
}
