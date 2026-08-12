class BatchCompletionSummary {
  const BatchCompletionSummary({
    required this.id,
    required this.inputCount,
    required this.savedCount,
    required this.verifiedCount,
    required this.needsReviewCount,
    required this.failedCount,
    required this.reclaimableCount,
    required this.reclaimableBytes,
    this.issueMessage,
  });

  final String id;
  final int inputCount;
  final int savedCount;
  final int verifiedCount;
  final int needsReviewCount;
  final int failedCount;
  final int reclaimableCount;
  final int reclaimableBytes;
  final String? issueMessage;

  bool get allFailed => failedCount == inputCount;
  bool get hasIssues => failedCount > 0 || needsReviewCount > 0;
  bool get canReclaim => reclaimableCount > 0;
}
