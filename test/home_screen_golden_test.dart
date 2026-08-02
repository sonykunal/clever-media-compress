import 'dart:ui' show Size;

import 'package:clever_media_compress/app.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  testWidgets('phone empty state matches the reviewed design', (tester) async {
    tester.view.devicePixelRatio = 1;
    tester.view.physicalSize = const Size(390, 844);
    addTearDown(tester.view.resetDevicePixelRatio);
    addTearDown(tester.view.resetPhysicalSize);

    await tester.pumpWidget(const CleverCompressApp());
    await tester.pump();

    await expectLater(
      find.byType(CleverCompressApp),
      matchesGoldenFile('goldens/home_screen.png'),
    );
  });
}
