import 'package:flutter/material.dart';

import '../../../../core/theme/app_theme.dart';
import '../../domain/compression_settings.dart';

class CompressionControls extends StatelessWidget {
  const CompressionControls({
    super.key,
    required this.settings,
    required this.enabled,
    required this.onQualityChanged,
    required this.onResolutionChanged,
    required this.onMetadataChanged,
    required this.onLocationChanged,
  });

  final CompressionSettings settings;
  final bool enabled;
  final ValueChanged<double> onQualityChanged;
  final ValueChanged<double> onResolutionChanged;
  final ValueChanged<bool> onMetadataChanged;
  final ValueChanged<bool> onLocationChanged;

  @override
  Widget build(BuildContext context) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'Compression recipe',
              style: TextStyle(fontSize: 18, fontWeight: FontWeight.w800),
            ),
            const SizedBox(height: 4),
            const Text(
              'One recipe is applied safely to every selected item.',
              style: TextStyle(color: AppColors.muted, fontSize: 13),
            ),
            const SizedBox(height: 24),
            Row(
              children: [
                const Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Image quality',
                        style: TextStyle(fontWeight: FontWeight.w700),
                      ),
                      SizedBox(height: 3),
                      Text(
                        'Higher keeps more fine detail',
                        style: TextStyle(color: AppColors.muted, fontSize: 12),
                      ),
                    ],
                  ),
                ),
                Container(
                  width: 64,
                  padding: const EdgeInsets.symmetric(vertical: 9),
                  decoration: BoxDecoration(
                    color: const Color(0xFFF0EEFF),
                    borderRadius: BorderRadius.circular(13),
                  ),
                  alignment: Alignment.center,
                  child: Text(
                    '${settings.quality}%',
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
              value: settings.quality.toDouble(),
              onChanged: enabled ? onQualityChanged : null,
            ),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: const [
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
            const Text(
              'Resolution',
              style: TextStyle(fontWeight: FontWeight.w700),
            ),
            const SizedBox(height: 10),
            Row(
              children: [
                _ResolutionOption(
                  label: 'Original',
                  caption: '100%',
                  selected: settings.resolutionScale == 1,
                  enabled: enabled,
                  onTap: () => onResolutionChanged(1),
                ),
                const SizedBox(width: 9),
                _ResolutionOption(
                  label: 'Balanced',
                  caption: '75%',
                  selected: settings.resolutionScale == .75,
                  enabled: enabled,
                  onTap: () => onResolutionChanged(.75),
                ),
                const SizedBox(width: 9),
                _ResolutionOption(
                  label: 'Compact',
                  caption: '50%',
                  selected: settings.resolutionScale == .5,
                  enabled: enabled,
                  onTap: () => onResolutionChanged(.5),
                ),
              ],
            ),
            const SizedBox(height: 24),
            const Divider(),
            const SizedBox(height: 10),
            _ProtectionSwitch(
              icon: Icons.verified_user_outlined,
              title: 'Preserve capture metadata',
              subtitle: 'Date taken, timezone, camera and orientation',
              value: settings.preserveMetadata,
              enabled: enabled,
              onChanged: onMetadataChanged,
            ),
            const SizedBox(height: 8),
            _ProtectionSwitch(
              icon: Icons.location_on_outlined,
              title: 'Preserve location',
              subtitle: 'Requires permission when GPS is present',
              value: settings.preserveLocation,
              enabled: enabled && settings.preserveMetadata,
              onChanged: onLocationChanged,
            ),
          ],
        ),
      ),
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
            color: selected ? const Color(0xFFF0EEFF) : Colors.white,
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
              color: const Color(0xFFECFDF3),
              borderRadius: BorderRadius.circular(13),
            ),
            child: Icon(icon, color: AppColors.success, size: 21),
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
          Switch.adaptive(
            value: value,
            activeTrackColor: AppColors.success,
            onChanged: enabled ? onChanged : null,
          ),
        ],
      ),
    );
  }
}
