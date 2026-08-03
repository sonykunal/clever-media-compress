import 'package:clever_media_compress/app.dart';
import 'package:clever_media_compress/core/utils/formatters.dart';
import 'package:clever_media_compress/features/compress/data/media_permission_service.dart';
import 'package:clever_media_compress/features/compress/domain/compression_settings.dart';
import 'package:clever_media_compress/features/compress/domain/media_asset.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('file sizes use compact, human-friendly units', () {
    expect(Formatters.fileSize(0), '0 B');
    expect(Formatters.fileSize(1536), '1.5 KB');
    expect(Formatters.fileSize(2 * 1024 * 1024), '2.0 MB');
  });

  test('photo and video recipes remain independent when copied', () {
    const settings = CompressionSettings();
    final changed = settings.copyWith(
      image: settings.image.copyWith(quality: 64),
      video: settings.video.copyWith(resolutionScale: .5),
      preserveLocation: false,
    );

    expect(changed.image.quality, 64);
    expect(changed.video.quality, settings.video.quality);
    expect(changed.video.resolutionScale, .5);
    expect(changed.recipeFor(MediaKind.image), same(changed.image));
    expect(changed.recipeFor(MediaKind.video), same(changed.video));
    expect(changed.preserveMetadata, isTrue);
    expect(changed.preserveLocation, isFalse);
    expect(changed.outputSuffix, '_compressed');
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

  testWidgets('home screen communicates the product promise', (tester) async {
    await tester.pumpWidget(const CleverCompressApp());
    await tester.pump();

    expect(find.text('Smaller media.\nSame moment.'), findsOneWidget);
    expect(find.text('Choose photos & videos'), findsOneWidget);
  });
}
