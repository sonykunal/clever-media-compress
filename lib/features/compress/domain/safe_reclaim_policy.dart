import 'compression_result.dart';
import 'media_asset.dart';

abstract final class SafeReclaimPolicy {
  static bool isEligible(SelectedMedia media, CompressionResult? result) {
    return result?.status == CompressionJobStatus.completed &&
        result!.captureDateVerified &&
        media.sourceAssetIdentifier?.isNotEmpty == true &&
        media.supportsRecoverableReclaim;
  }
}
