import 'package:clever_media_compress/app.dart';
import 'package:clever_media_compress/core/utils/formatters.dart';
import 'package:clever_media_compress/features/compress/domain/compression_settings.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('file sizes use compact, human-friendly units', () {
    expect(Formatters.fileSize(0), '0 B');
    expect(Formatters.fileSize(1536), '1.5 KB');
    expect(Formatters.fileSize(2 * 1024 * 1024), '2.0 MB');
  });

  test('settings preserve safe defaults when copied', () {
    const settings = CompressionSettings();
    final changed = settings.copyWith(quality: 64, preserveLocation: false);

    expect(changed.quality, 64);
    expect(changed.preserveMetadata, isTrue);
    expect(changed.preserveLocation, isFalse);
    expect(changed.outputSuffix, '_compressed');
  });

  testWidgets('home screen communicates the product promise', (tester) async {
    await tester.pumpWidget(const CleverCompressApp());
    await tester.pump();

    expect(find.text('Smaller media.\nSame moment.'), findsOneWidget);
    expect(find.text('Choose photos & videos'), findsOneWidget);
  });
}
