class CompressionSettings {
  const CompressionSettings({
    this.quality = 72,
    this.resolutionScale = 1,
    this.preserveMetadata = true,
    this.preserveLocation = true,
    this.outputSuffix = '_compressed',
  });

  final int quality;
  final double resolutionScale;
  final bool preserveMetadata;
  final bool preserveLocation;
  final String outputSuffix;

  int get reductionPercent => 100 - quality;

  CompressionSettings copyWith({
    int? quality,
    double? resolutionScale,
    bool? preserveMetadata,
    bool? preserveLocation,
    String? outputSuffix,
  }) {
    return CompressionSettings(
      quality: quality ?? this.quality,
      resolutionScale: resolutionScale ?? this.resolutionScale,
      preserveMetadata: preserveMetadata ?? this.preserveMetadata,
      preserveLocation: preserveLocation ?? this.preserveLocation,
      outputSuffix: outputSuffix ?? this.outputSuffix,
    );
  }
}
