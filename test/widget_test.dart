import 'package:clever_media_compress/app.dart';
import 'package:clever_media_compress/core/utils/formatters.dart';
import 'package:clever_media_compress/features/compress/data/media_permission_service.dart';
import 'package:clever_media_compress/features/compress/data/media_picker_service.dart';
import 'package:clever_media_compress/features/compress/data/platform_media_service.dart';
import 'package:clever_media_compress/features/compress/data/preview_service.dart';
import 'package:clever_media_compress/features/compress/domain/compression_settings.dart';
import 'package:clever_media_compress/features/compress/domain/compression_result.dart';
import 'package:clever_media_compress/features/compress/domain/batch_completion_summary.dart';
import 'package:clever_media_compress/features/compress/domain/media_asset.dart';
import 'package:clever_media_compress/features/compress/domain/reclaim_result.dart';
import 'package:clever_media_compress/features/compress/domain/safe_reclaim_policy.dart';
import 'package:clever_media_compress/features/compress/presentation/compress_controller.dart';
import 'package:clever_media_compress/features/compress/presentation/compress_screen.dart';
import 'package:clever_media_compress/features/compress/presentation/success_portal_screen.dart';
import 'package:clever_media_compress/features/compress/presentation/widgets/comparison_preview.dart';
import 'package:clever_media_compress/features/compress/presentation/widgets/compression_controls.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('file sizes use compact, human-friendly units', () {
    expect(Formatters.fileSize(0), '0 B');
    expect(Formatters.fileSize(1536), '1.5 KB');
    expect(Formatters.fileSize(2 * 1024 * 1024), '2.0 MB');
  });

  test('recipes remain independent and protection guarantees stay enabled', () {
    const settings = CompressionSettings();
    final changed = settings.copyWith(
      image: settings.image.copyWith(quality: 64),
      video: settings.video.copyWith(resolutionScale: .5),
    );

    expect(changed.image.quality, 64);
    expect(changed.video.quality, settings.video.quality);
    expect(changed.video.resolutionScale, .5);
    expect(changed.recipeFor(MediaKind.image), same(changed.image));
    expect(changed.recipeFor(MediaKind.video), same(changed.video));
    expect(changed.preserveMetadata, isTrue);
    expect(changed.preserveLocation, isTrue);
    expect(changed.outputSuffix, '_compressed');
  });

  testWidgets('metadata protections are read-only without switches', (
    tester,
  ) async {
    tester.view.devicePixelRatio = 1;
    tester.view.physicalSize = const Size(320, 700);
    addTearDown(tester.view.resetDevicePixelRatio);
    addTearDown(tester.view.resetPhysicalSize);

    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: SingleChildScrollView(
            padding: const EdgeInsets.all(12),
            child: CompressionControls(
              imageRecipe: const MediaCompressionRecipe(),
              videoRecipe: const MediaCompressionRecipe(),
              imageCount: 1,
              videoCount: 0,
              enabled: true,
              onImageQualityChanged: (_) {},
              onImageResolutionChanged: (_) {},
              onVideoQualityChanged: (_) {},
              onVideoResolutionChanged: (_) {},
            ),
          ),
        ),
      ),
    );

    expect(find.text('Preserve capture metadata'), findsOneWidget);
    expect(find.text('Preserve location'), findsOneWidget);
    expect(find.textContaining('Always on'), findsNWidgets(2));
    expect(find.byType(Switch), findsNothing);
    expect(find.byType(SwitchListTile), findsNothing);
    expect(tester.takeException(), isNull);
  });

  test(
    'video output estimate uses quality and resolution without overpromising',
    () {
      const recipe = MediaCompressionRecipe(quality: 50, resolutionScale: .5);
      final estimated = recipe.estimateOutputBytes(20 * 1024 * 1024);

      expect(estimated, 2621440);
      expect(estimated, lessThan(20 * 1024 * 1024));
    },
  );

  testWidgets('video uses the interactive comparison without metric labels', (
    tester,
  ) async {
    tester.view.devicePixelRatio = 1;
    tester.view.physicalSize = const Size(390, 844);
    addTearDown(tester.view.resetDevicePixelRatio);
    addTearDown(tester.view.resetPhysicalSize);

    await tester.pumpWidget(
      const MaterialApp(
        home: Scaffold(
          body: SingleChildScrollView(
            padding: EdgeInsets.all(18),
            child: ComparisonPreview(
              media: SelectedMedia(
                id: 'video-preview',
                path: '/temporary/video.mp4',
                name: 'video.mp4',
                byteSize: 20 * 1024 * 1024,
                kind: MediaKind.video,
              ),
              recipe: MediaCompressionRecipe(quality: 50, resolutionScale: .5),
              preview: null,
              loading: false,
            ),
          ),
        ),
      ),
    );

    expect(find.text('Live comparison'), findsOneWidget);
    expect(find.text('ORIGINAL'), findsOneWidget);
    expect(find.text('ESTIMATED'), findsOneWidget);
    expect(find.text('2.5 MB'), findsOneWidget);
    expect(find.byTooltip('Zoom in'), findsOneWidget);
    expect(find.text('Reset'), findsOneWidget);
    expect(find.textContaining('Quality'), findsNothing);
    expect(find.textContaining('Preview frame'), findsNothing);
    expect(find.textContaining('Container'), findsNothing);

    await tester.tap(find.byTooltip('Zoom in'));
    await tester.pumpAndSettle();

    expect(tester.takeException(), isNull);
  });

  test('media permission channel payload is parsed consistently', () {
    final result = MediaAccessResult.fromMap({
      'status': 'limited',
      'message': 'Limited access',
      'canOpenSettings': true,
    });

    expect(result.status, MediaAccessStatus.limited);
    expect(result.message, 'Limited access');
    expect(result.canOpenSettings, isTrue);
    expect(result.hasFullAccess, isFalse);
  });

  test(
    'storage reclaim requires verified output and recoverable native asset',
    () {
      const identified = SelectedMedia(
        id: 'photo-1',
        path: '/temporary/photo.jpg',
        name: 'photo.jpg',
        byteSize: 1024,
        kind: MediaKind.image,
        sourceAssetIdentifier: 'native-gallery-id',
        supportsRecoverableReclaim: true,
      );
      const anonymous = SelectedMedia(
        id: 'photo-2',
        path: '/temporary/shared.jpg',
        name: 'shared.jpg',
        byteSize: 1024,
        kind: MediaKind.image,
      );
      const permanentDeleteOnly = SelectedMedia(
        id: 'photo-3',
        path: '/temporary/legacy.jpg',
        name: 'legacy.jpg',
        byteSize: 1024,
        kind: MediaKind.image,
        sourceAssetIdentifier: 'legacy-gallery-id',
      );
      const verified = CompressionResult(
        sourceId: 'photo-1',
        status: CompressionJobStatus.completed,
        captureDateVerified: true,
      );
      const needsReview = CompressionResult(
        sourceId: 'photo-1',
        status: CompressionJobStatus.completed,
        captureDateVerified: false,
      );

      expect(SafeReclaimPolicy.isEligible(identified, verified), isTrue);
      expect(SafeReclaimPolicy.isEligible(identified, needsReview), isFalse);
      expect(SafeReclaimPolicy.isEligible(anonymous, verified), isFalse);
      expect(
        SafeReclaimPolicy.isEligible(permanentDeleteOnly, verified),
        isFalse,
      );
    },
  );

  testWidgets('home screen communicates the product promise', (tester) async {
    await tester.pumpWidget(const CleverCompressApp());
    await tester.pump();

    expect(find.text('Smaller media.\nSame moment.'), findsOneWidget);
    expect(find.text('Choose photos & videos'), findsOneWidget);
  });

  testWidgets('success portal presents reclaim without a new-batch button', (
    tester,
  ) async {
    tester.view.devicePixelRatio = 1;
    tester.view.physicalSize = const Size(390, 844);
    addTearDown(tester.view.resetDevicePixelRatio);
    addTearDown(tester.view.resetPhysicalSize);
    final controller = CompressController(
      picker: _FakeMediaPickerService(),
      permissionService: _FakeMediaPermissionService(),
      previewService: PreviewService(),
      platformService: _FakePlatformMediaService(),
    );
    addTearDown(controller.dispose);

    await tester.pumpWidget(
      MaterialApp(
        home: SuccessPortalScreen(
          controller: controller,
          onFinished: (_) {},
          summary: const BatchCompletionSummary(
            id: 'portal-test',
            inputCount: 1,
            savedCount: 1,
            verifiedCount: 1,
            needsReviewCount: 0,
            failedCount: 0,
            reclaimableCount: 1,
            reclaimableBytes: 4096,
          ),
        ),
      ),
    );

    expect(find.text('Compression complete!'), findsOneWidget);
    expect(find.text('4.0 KB'), findsNWidgets(2));
    expect(find.text('Move originals to Trash'), findsOneWidget);
    expect(find.byIcon(Icons.delete_outline_rounded), findsOneWidget);
    expect(find.text('Keep originals'), findsOneWidget);
    expect(find.text('Start a new batch'), findsNothing);
    expect(tester.takeException(), isNull);

    tester.view.physicalSize = const Size(320, 700);
    await tester.pump();

    expect(find.text('Move originals to Trash'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets(
    'completion swaps directly to portal without a home-screen frame',
    (tester) async {
      final controller = CompressController(
        picker: _FakeMediaPickerService(),
        permissionService: _FakeMediaPermissionService(),
        previewService: PreviewService(),
        platformService: _FakePlatformMediaService(),
      );
      addTearDown(controller.dispose);
      await tester.pumpWidget(
        MaterialApp(home: CompressScreen(controller: controller)),
      );

      await controller.selectMedia();
      await tester.pump();
      expect(find.text('Choose photos & videos'), findsNothing);

      await controller.startBatch();
      await tester.pump();

      expect(find.text('Compression complete!'), findsOneWidget);
      expect(find.text('Choose photos & videos'), findsNothing);
      expect(tester.takeException(), isNull);
    },
  );

  test(
    'completed batch resets selection but retains safe reclaim receipt',
    () async {
      final platform = _FakePlatformMediaService();
      final controller = CompressController(
        picker: _FakeMediaPickerService(),
        permissionService: _FakeMediaPermissionService(),
        previewService: PreviewService(),
        platformService: platform,
      );
      addTearDown(controller.dispose);

      await controller.selectMedia();
      expect(controller.hasMedia, isTrue);

      await controller.startBatch();

      expect(controller.hasMedia, isFalse);
      expect(controller.completionSummary?.savedCount, 1);
      expect(controller.completionSummary?.verifiedCount, 1);
      expect(controller.completionSummary?.reclaimableCount, 1);
      expect(controller.reclaimableMedia, hasLength(1));

      await controller.reclaimOriginals();
      expect(controller.originalsReclaimed, isTrue);
      expect(platform.reclaimedItems, hasLength(1));

      controller.dismissCompletion();
      expect(controller.completionSummary, isNull);
      expect(controller.reclaimableMedia, isEmpty);
    },
  );
}

class _FakeMediaPickerService extends MediaPickerService {
  @override
  Future<List<SelectedMedia>> pickMedia() async => const [
    SelectedMedia(
      id: 'video-1',
      path: '/temporary/video.mp4',
      name: 'video.mp4',
      byteSize: 4096,
      kind: MediaKind.video,
      sourceAssetIdentifier: 'native-video-id',
      supportsRecoverableReclaim: true,
    ),
  ];
}

class _FakeMediaPermissionService extends MediaPermissionService {
  @override
  Future<MediaAccessResult> requestFullAccess() async =>
      const MediaAccessResult(
        status: MediaAccessStatus.full,
        message: 'Allowed in test.',
      );
}

class _FakePlatformMediaService extends PlatformMediaService {
  List<SelectedMedia> reclaimedItems = const [];

  @override
  Future<CompressionResult> compressAndPublish(
    SelectedMedia media,
    CompressionSettings settings,
  ) async => CompressionResult(
    sourceId: media.id,
    status: CompressionJobStatus.completed,
    outputUri: 'gallery://compressed-video',
    outputName: 'video_compressed.mp4',
    outputBytes: 2048,
    captureDateVerified: true,
  );

  @override
  Future<ReclaimResult> reclaimOriginals(List<SelectedMedia> media) async {
    reclaimedItems = List.unmodifiable(media);
    return const ReclaimResult(
      success: true,
      reclaimedCount: 1,
      reclaimedBytes: 4096,
      message: 'Original moved to Trash.',
    );
  }
}
