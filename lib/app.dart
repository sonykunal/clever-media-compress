import 'package:flutter/material.dart';

import 'core/theme/app_theme.dart';
import 'features/compress/data/media_picker_service.dart';
import 'features/compress/data/media_permission_service.dart';
import 'features/compress/data/platform_media_service.dart';
import 'features/compress/data/preview_service.dart';
import 'features/compress/presentation/compress_controller.dart';
import 'features/compress/presentation/compress_screen.dart';

class CleverCompressApp extends StatefulWidget {
  const CleverCompressApp({super.key});

  @override
  State<CleverCompressApp> createState() => _CleverCompressAppState();
}

class _CleverCompressAppState extends State<CleverCompressApp>
    with WidgetsBindingObserver {
  late final CompressController _controller;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _controller = CompressController(
      picker: MediaPickerService(),
      permissionService: MediaPermissionService(),
      previewService: PreviewService(),
      platformService: PlatformMediaService(),
    )..initialize();
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _controller.dispose();
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) {
      _controller.consumeSharedMedia();
    }
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
