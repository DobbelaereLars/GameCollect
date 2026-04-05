import 'package:flutter/material.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';

import '../../../../core/theme/app_theme.dart';

class DiscoverSearchBar extends StatelessWidget {
  const DiscoverSearchBar({
    required this.controller,
    required this.onChanged,
    required this.onSubmitted,
    required this.onClearPressed,
    required this.showCameraButton,
    required this.onCameraPressed,
    required this.isCameraBusy,
    required this.isCameraDisabled,
    super.key,
  });

  final TextEditingController controller;
  final ValueChanged<String> onChanged;
  final ValueChanged<String> onSubmitted;
  final VoidCallback onClearPressed;
  final bool showCameraButton;
  final VoidCallback onCameraPressed;
  final bool isCameraBusy;
  final bool isCameraDisabled;

  @override
  Widget build(BuildContext context) {
    final textTheme = Theme.of(context).textTheme;

    return Row(
      children: [
        Expanded(
          child: TextField(
            controller: controller,
            textInputAction: TextInputAction.search,
            onChanged: onChanged,
            onSubmitted: onSubmitted,
            style: textTheme.bodyLarge?.copyWith(color: AppTheme.black),
            decoration: InputDecoration(
              hintText: 'Zoek games...',
              hintStyle: textTheme.bodyLarge?.copyWith(
                color: AppTheme.grayTransparent50,
              ),
              isDense: true,
              contentPadding: const EdgeInsets.symmetric(vertical: 10),
              filled: true,
              fillColor: AppTheme.orange50,
              prefixIcon: const Icon(
                LucideIcons.search,
                color: AppTheme.orange500,
                size: 20,
              ),
              suffixIcon: ValueListenableBuilder<TextEditingValue>(
                valueListenable: controller,
                builder: (context, value, child) {
                  final hasQuery = value.text.trim().isNotEmpty;
                  if (!hasQuery) {
                    return const SizedBox.shrink();
                  }

                  return IconButton(
                    onPressed: onClearPressed,
                    tooltip: 'Wis zoekterm',
                    icon: const Icon(
                      LucideIcons.x,
                      color: AppTheme.gray700,
                      size: 16,
                    ),
                  );
                },
              ),
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(12),
                borderSide: const BorderSide(color: AppTheme.orange200),
              ),
              enabledBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(12),
                borderSide: const BorderSide(color: AppTheme.orange200),
              ),
              focusedBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(12),
                borderSide: const BorderSide(color: AppTheme.orange500),
              ),
            ),
          ),
        ),
        if (showCameraButton) ...[
          const SizedBox(width: 12),
          IconButton(
            tooltip: 'Scan cover',
            onPressed: isCameraDisabled ? null : onCameraPressed,
            style: const ButtonStyle(
              overlayColor: WidgetStatePropertyAll(Colors.transparent),
            ),
            icon: isCameraBusy
                ? const SizedBox(
                    width: 20,
                    height: 20,
                    child: CircularProgressIndicator(
                      strokeWidth: 2,
                      color: AppTheme.orange500,
                    ),
                  )
                : const Icon(LucideIcons.camera, color: AppTheme.orange500),
          ),
        ],
      ],
    );
  }
}
