import 'package:flutter/material.dart';

import '../../../../core/theme/app_theme.dart';
import '../../domain/compression_settings.dart';

enum _RecipeTab { image, video }

class CompressionControls extends StatefulWidget {
  const CompressionControls({
    super.key,
    required this.imageRecipe,
    required this.videoRecipe,
    required this.imageCount,
    required this.videoCount,
    required this.preserveMetadata,
    required this.preserveLocation,
    required this.enabled,
    required this.onImageQualityChanged,
    required this.onImageResolutionChanged,
    required this.onVideoQualityChanged,
    required this.onVideoResolutionChanged,
    required this.onMetadataChanged,
    required this.onLocationChanged,
  });

  final MediaCompressionRecipe imageRecipe;
  final MediaCompressionRecipe videoRecipe;
  final int imageCount;
  final int videoCount;
  final bool preserveMetadata;
  final bool preserveLocation;
  final bool enabled;
  final ValueChanged<double> onImageQualityChanged;
  final ValueChanged<double> onImageResolutionChanged;
  final ValueChanged<double> onVideoQualityChanged;
  final ValueChanged<double> onVideoResolutionChanged;
  final ValueChanged<bool> onMetadataChanged;
  final ValueChanged<bool> onLocationChanged;

  @override
  State<CompressionControls> createState() => _CompressionControlsState();
}

class _CompressionControlsState extends State<CompressionControls> {
  late _RecipeTab _selectedTab;

  @override
  void initState() {
    super.initState();
    _selectedTab = widget.imageCount > 0 ? _RecipeTab.image : _RecipeTab.video;
  }

  @override
  void didUpdateWidget(covariant CompressionControls oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (_selectedTab == _RecipeTab.image && widget.imageCount == 0) {
      _selectedTab = _RecipeTab.video;
    } else if (_selectedTab == _RecipeTab.video && widget.videoCount == 0) {
      _selectedTab = _RecipeTab.image;
    }
  }

  @override
  Widget build(BuildContext context) {
    final hasBothTypes = widget.imageCount > 0 && widget.videoCount > 0;
    final showingImages = _selectedTab == _RecipeTab.image;

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'Compression recipes',
              style: TextStyle(fontSize: 18, fontWeight: FontWeight.w800),
            ),
            const SizedBox(height: 4),
            Text(
              hasBothTypes
                  ? 'Tune photos and videos separately. Each item uses its matching recipe.'
                  : showingImages
                  ? 'This recipe applies only to your selected photos.'
                  : 'This recipe applies only to your selected videos.',
              style: const TextStyle(color: AppColors.muted, fontSize: 13),
            ),
            const SizedBox(height: 18),
            if (hasBothTypes) ...[
              Semantics(
                label: 'Choose photo or video compression settings',
                child: SegmentedButton<_RecipeTab>(
                  segments: [
                    ButtonSegment(
                      value: _RecipeTab.image,
                      icon: const Icon(Icons.photo_outlined, size: 18),
                      label: Text('Photos (${widget.imageCount})'),
                    ),
                    ButtonSegment(
                      value: _RecipeTab.video,
                      icon: const Icon(Icons.videocam_outlined, size: 18),
                      label: Text('Videos (${widget.videoCount})'),
                    ),
                  ],
                  selected: {_selectedTab},
                  onSelectionChanged: widget.enabled
                      ? (selection) => setState(() {
                          _selectedTab = selection.first;
                        })
                      : null,
                  showSelectedIcon: false,
                  style: ButtonStyle(
                    visualDensity: VisualDensity.compact,
                    foregroundColor: WidgetStateProperty.resolveWith(
                      (states) => states.contains(WidgetState.selected)
                          ? AppColors.brandDark
                          : AppColors.muted,
                    ),
                    backgroundColor: WidgetStateProperty.resolveWith(
                      (states) => states.contains(WidgetState.selected)
                          ? AppColors.violetMist
                          : Colors.white,
                    ),
                  ),
                ),
              ),
              const SizedBox(height: 22),
            ] else
              _RecipeLabel(
                icon: showingImages
                    ? Icons.photo_outlined
                    : Icons.videocam_outlined,
                label: showingImages
                    ? '${widget.imageCount} photo${widget.imageCount == 1 ? '' : 's'}'
                    : '${widget.videoCount} video${widget.videoCount == 1 ? '' : 's'}',
              ),
            AnimatedSwitcher(
              duration: const Duration(milliseconds: 180),
              child: _RecipeEditor(
                key: ValueKey(_selectedTab),
                recipe: showingImages ? widget.imageRecipe : widget.videoRecipe,
                isVideo: !showingImages,
                enabled: widget.enabled,
                onQualityChanged: showingImages
                    ? widget.onImageQualityChanged
                    : widget.onVideoQualityChanged,
                onResolutionChanged: showingImages
                    ? widget.onImageResolutionChanged
                    : widget.onVideoResolutionChanged,
              ),
            ),
            const SizedBox(height: 24),
            const Divider(color: AppColors.border),
            const SizedBox(height: 10),
            _ProtectionSwitch(
              icon: Icons.verified_user_outlined,
              title: 'Preserve capture metadata',
              subtitle: 'Applied to every selected photo and video',
              value: widget.preserveMetadata,
              enabled: widget.enabled,
              onChanged: widget.onMetadataChanged,
            ),
            const SizedBox(height: 8),
            _ProtectionSwitch(
              icon: Icons.location_on_outlined,
              title: 'Preserve location',
              subtitle: 'Applied when GPS metadata is present',
              value: widget.preserveLocation,
              enabled: widget.enabled && widget.preserveMetadata,
              onChanged: widget.onLocationChanged,
            ),
          ],
        ),
      ),
    );
  }
}

class _RecipeLabel extends StatelessWidget {
  const _RecipeLabel({required this.icon, required this.label});

  final IconData icon;
  final String label;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 18),
      child: Row(
        children: [
          Icon(icon, color: AppColors.brand, size: 19),
          const SizedBox(width: 8),
          Text(
            label,
            style: const TextStyle(
              color: AppColors.brandDark,
              fontSize: 13,
              fontWeight: FontWeight.w800,
            ),
          ),
        ],
      ),
    );
  }
}

class _RecipeEditor extends StatelessWidget {
  const _RecipeEditor({
    super.key,
    required this.recipe,
    required this.isVideo,
    required this.enabled,
    required this.onQualityChanged,
    required this.onResolutionChanged,
  });

  final MediaCompressionRecipe recipe;
  final bool isVideo;
  final bool enabled;
  final ValueChanged<double> onQualityChanged;
  final ValueChanged<double> onResolutionChanged;

  @override
  Widget build(BuildContext context) {
    final mediaLabel = isVideo ? 'Video' : 'Photo';
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    '$mediaLabel quality',
                    style: const TextStyle(fontWeight: FontWeight.w700),
                  ),
                  const SizedBox(height: 3),
                  Text(
                    isVideo
                        ? 'Controls video bitrate and visible detail'
                        : 'Higher keeps more fine detail',
                    style: const TextStyle(
                      color: AppColors.muted,
                      fontSize: 12,
                    ),
                  ),
                ],
              ),
            ),
            Container(
              width: 64,
              padding: const EdgeInsets.symmetric(vertical: 9),
              decoration: BoxDecoration(
                color: AppColors.violetMist,
                borderRadius: BorderRadius.circular(13),
                border: Border.all(color: AppColors.violetSoft),
              ),
              alignment: Alignment.center,
              child: Text(
                '${recipe.quality}%',
                style: const TextStyle(
                  color: AppColors.brandDark,
                  fontSize: 16,
                  fontWeight: FontWeight.w800,
                ),
              ),
            ),
          ],
        ),
        const SizedBox(height: 7),
        Slider(
          min: 20,
          max: 95,
          divisions: 75,
          value: recipe.quality.toDouble(),
          onChanged: enabled ? onQualityChanged : null,
        ),
        const Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Text(
              'Smaller file',
              style: TextStyle(color: AppColors.muted, fontSize: 11),
            ),
            Text(
              'Best detail',
              style: TextStyle(color: AppColors.muted, fontSize: 11),
            ),
          ],
        ),
        const SizedBox(height: 25),
        Text(
          isVideo ? 'Video frame size' : 'Photo resolution',
          style: const TextStyle(fontWeight: FontWeight.w700),
        ),
        const SizedBox(height: 4),
        Text(
          isVideo
              ? 'Smaller frames reduce video size and export time.'
              : 'Smaller dimensions reduce image size most effectively.',
          style: const TextStyle(color: AppColors.muted, fontSize: 12),
        ),
        const SizedBox(height: 10),
        Row(
          children: [
            _ResolutionOption(
              label: 'Original',
              caption: '100%',
              selected: recipe.resolutionScale == 1,
              enabled: enabled,
              onTap: () => onResolutionChanged(1),
            ),
            const SizedBox(width: 9),
            _ResolutionOption(
              label: 'Balanced',
              caption: '75%',
              selected: recipe.resolutionScale == .75,
              enabled: enabled,
              onTap: () => onResolutionChanged(.75),
            ),
            const SizedBox(width: 9),
            _ResolutionOption(
              label: 'Compact',
              caption: '50%',
              selected: recipe.resolutionScale == .5,
              enabled: enabled,
              onTap: () => onResolutionChanged(.5),
            ),
          ],
        ),
      ],
    );
  }
}

class _ResolutionOption extends StatelessWidget {
  const _ResolutionOption({
    required this.label,
    required this.caption,
    required this.selected,
    required this.enabled,
    required this.onTap,
  });

  final String label;
  final String caption;
  final bool selected;
  final bool enabled;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Expanded(
      child: InkWell(
        onTap: enabled ? onTap : null,
        borderRadius: BorderRadius.circular(15),
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 180),
          padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 5),
          decoration: BoxDecoration(
            color: selected ? AppColors.violetMist : Colors.white,
            borderRadius: BorderRadius.circular(15),
            border: Border.all(
              color: selected ? AppColors.brand : AppColors.border,
              width: selected ? 1.5 : 1,
            ),
          ),
          child: Column(
            children: [
              Text(
                label,
                style: TextStyle(
                  color: selected ? AppColors.brandDark : AppColors.ink,
                  fontSize: 12,
                  fontWeight: FontWeight.w700,
                ),
              ),
              const SizedBox(height: 2),
              Text(
                caption,
                style: const TextStyle(color: AppColors.muted, fontSize: 10),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _ProtectionSwitch extends StatelessWidget {
  const _ProtectionSwitch({
    required this.icon,
    required this.title,
    required this.subtitle,
    required this.value,
    required this.enabled,
    required this.onChanged,
  });

  final IconData icon;
  final String title;
  final String subtitle;
  final bool value;
  final bool enabled;
  final ValueChanged<bool> onChanged;

  @override
  Widget build(BuildContext context) {
    return Opacity(
      opacity: enabled ? 1 : .48,
      child: Row(
        children: [
          Container(
            width: 42,
            height: 42,
            decoration: BoxDecoration(
              color: AppColors.violetMist,
              borderRadius: BorderRadius.circular(13),
              border: Border.all(color: AppColors.violetSoft),
            ),
            child: Icon(icon, color: AppColors.brand, size: 21),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: const TextStyle(
                    fontSize: 13,
                    fontWeight: FontWeight.w700,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  subtitle,
                  style: const TextStyle(
                    color: AppColors.muted,
                    fontSize: 10.5,
                  ),
                ),
              ],
            ),
          ),
          Switch.adaptive(value: value, onChanged: enabled ? onChanged : null),
        ],
      ),
    );
  }
}
