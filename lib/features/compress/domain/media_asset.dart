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
  });

  final String id;
  final String path;
  final String name;
  final int byteSize;
  final MediaKind kind;
  final String? mimeType;
  final int? width;
  final int? height;

  bool get isImage => kind == MediaKind.image;
  String get extension {
    final dot = name.lastIndexOf('.');
    return dot == -1 ? '' : name.substring(dot + 1).toLowerCase();
  }
}
