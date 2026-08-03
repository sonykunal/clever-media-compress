import 'media_asset.dart';

/// Quality and frame-size choices for one media category.
class MediaCompressionRecipe {
  const MediaCompressionRecipe({this.quality = 72, this.resolutionScale = 1});

  final int quality;
  final double resolutionScale;

  int get reductionPercent => 100 - quality;

  MediaCompressionRecipe copyWith({int? quality, double? resolutionScale}) {
    return MediaCompressionRecipe(
      quality: quality ?? this.quality,
      resolutionScale: resolutionScale ?? this.resolutionScale,
    );
  }
}

/// Batch-wide privacy choices plus separate recipes for photos and videos.
class CompressionSettings {
  const CompressionSettings({
    this.image = const MediaCompressionRecipe(),
    this.video = const MediaCompressionRecipe(
      quality: 68,
      resolutionScale: .75,
    ),
    this.preserveMetadata = true,
    this.preserveLocation = true,
    this.outputSuffix = '_compressed',
  });

  final MediaCompressionRecipe image;
  final MediaCompressionRecipe video;
  final bool preserveMetadata;
  final bool preserveLocation;
  final String outputSuffix;

  MediaCompressionRecipe recipeFor(MediaKind kind) => switch (kind) {
    MediaKind.image => image,
    MediaKind.video => video,
  };

  CompressionSettings copyWith({
    MediaCompressionRecipe? image,
    MediaCompressionRecipe? video,
    bool? preserveMetadata,
    bool? preserveLocation,
    String? outputSuffix,
  }) {
    return CompressionSettings(
      image: image ?? this.image,
      video: video ?? this.video,
      preserveMetadata: preserveMetadata ?? this.preserveMetadata,
      preserveLocation: preserveLocation ?? this.preserveLocation,
      outputSuffix: outputSuffix ?? this.outputSuffix,
    );
  }
}
