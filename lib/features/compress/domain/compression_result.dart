enum CompressionJobStatus { waiting, processing, completed, failed }

class CompressionResult {
  const CompressionResult({
    required this.sourceId,
    required this.status,
    this.outputUri,
    this.outputName,
    this.outputBytes,
    this.captureDateVerified = false,
    this.message,
  });

  final String sourceId;
  final CompressionJobStatus status;
  final String? outputUri;
  final String? outputName;
  final int? outputBytes;
  final bool captureDateVerified;
  final String? message;

  CompressionResult copyWith({
    CompressionJobStatus? status,
    String? outputUri,
    String? outputName,
    int? outputBytes,
    bool? captureDateVerified,
    String? message,
  }) {
    return CompressionResult(
      sourceId: sourceId,
      status: status ?? this.status,
      outputUri: outputUri ?? this.outputUri,
      outputName: outputName ?? this.outputName,
      outputBytes: outputBytes ?? this.outputBytes,
      captureDateVerified: captureDateVerified ?? this.captureDateVerified,
      message: message ?? this.message,
    );
  }
}
