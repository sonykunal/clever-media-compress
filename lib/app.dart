import 'package:flutter/material.dart';

import 'core/theme/app_theme.dart';
import 'features/compress/data/media_picker_service.dart';
import 'features/compress/data/platform_media_service.dart';
import 'features/compress/data/preview_service.dart';
import 'features/compress/presentation/compress_controller.dart';
import 'features/compress/presentation/compress_screen.dart';

class CleverCompressApp extends StatefulWidget {
  const CleverCompressApp({super.key});

  @override
  State<CleverCompressApp> createState() => _CleverCompressAppState();
}

class _CleverCompressAppState extends State<CleverCompressApp> {
  late final CompressController _controller;

  @override
  void initState() {
    super.initState();
    _controller = CompressController(
      picker: MediaPickerService(),
      previewService: PreviewService(),
      platformService: PlatformMediaService(),
    )..initialize();
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Clever Compress',
      debugShowCheckedModeBanner: false,
      theme: AppTheme.light,
      home: CompressScreen(controller: _controller),
    );
  }
}
