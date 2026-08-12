class ReclaimResult {
  const ReclaimResult({
    required this.success,
    required this.reclaimedCount,
    required this.reclaimedBytes,
    required this.message,
  });

  final bool success;
  final int reclaimedCount;
  final int reclaimedBytes;
  final String message;
}
