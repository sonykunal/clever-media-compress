enum MediaKind { image, video }

class SelectedMedia {
  const SelectedMedia({
    required this.id,
    required this.path,
    required this.name,
    required this.byteSize,
    required this.kind,
    this.mimeType,
    this.width,
    this.height,
    this.thumbnailPath,
    this.sourceUri,
    this.sourceRelativePath,
    this.sourceCaptureMillis,
    this.sourceAssetIdentifier,
    this.sourceAlbumIdentifiers = const [],
    this.supportsRecoverableReclaim = false,
  });

  final String id;
  final String path;
  final String name;
  final int byteSize;
  final MediaKind kind;
  final String? mimeType;
  final int? width;
  final int? height;
  final String? thumbnailPath;
  final String? sourceUri;
  final String? sourceRelativePath;
  final int? sourceCaptureMillis;
  final String? sourceAssetIdentifier;
  final List<String> sourceAlbumIdentifiers;
  final bool supportsRecoverableReclaim;

  bool get isImage => kind == MediaKind.image;
  String get extension {
    final dot = name.lastIndexOf('.');
    return dot == -1 ? '' : name.substring(dot + 1).toLowerCase();
  }
}
