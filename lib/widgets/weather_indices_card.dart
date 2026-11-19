import 'package:flutter/material.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';
import 'package:flutter_animate/flutter_animate.dart';
import '../app_localizations.dart';
import '../core/constants/app_constants.dart';
import '../models/weather_models.dart';
import 'glass/aurora_glass_card.dart';
import 'glass/glass_card_header.dart';

class WeatherIndicesCard extends StatelessWidget {
  final List<WeatherIndices> indices;

  const WeatherIndicesCard({super.key, required this.indices});

  @override
  Widget build(BuildContext context) {
    if (indices.isEmpty) return const SizedBox.shrink();

    // 只取前6个指数
    final displayIndices = indices.take(6).toList();

    return AuroraGlassCard(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          GlassCardHeader(
            icon: LucideIcons.lightbulb,
            title: context.tr('生活指数'),
          ),
          const SizedBox(height: 16),
          // 网格：窄屏 3 列、宽屏 6 列，卡片内不再被拉空。
          LayoutBuilder(
            builder: (context, constraints) {
              final cols = constraints.maxWidth >= kGridWideThreshold ? 6 : 3;
              const gap = 12.0;
              final itemWidth =
                  (constraints.maxWidth - gap * (cols - 1)) / cols;

              return Wrap(
                spacing: gap,
                runSpacing: gap,
                children: [
                  for (final index in displayIndices)
                    SizedBox(
                      width: itemWidth,
                      child: _IndexItem(index: index),
                    ),
                ],
              );
            },
          ),
        ],
      ),
    ).animate().fadeIn(duration: 400.ms).slideY(begin: 0.1);
  }
}

class _IndexItem extends StatelessWidget {
  final WeatherIndices index;

  const _IndexItem({required this.index});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 8),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(
            _getIndexIcon(index.type),
            color: Theme.of(context).colorScheme.primary,
            size: 24,
          ),
          const SizedBox(height: 8),
          Text(
            context.tr(index.name),
            style: Theme.of(context).textTheme.bodySmall?.copyWith(
              color: Theme.of(context).colorScheme.onSurfaceVariant,
            ),
            textAlign: TextAlign.center,
            maxLines: 2,
            overflow: TextOverflow.ellipsis,
          ),
          const SizedBox(height: 4),
          Text(
            context.tr(index.category),
            style: Theme.of(
              context,
            ).textTheme.titleSmall?.copyWith(fontWeight: FontWeight.w500),
            textAlign: TextAlign.center,
            maxLines: 2,
            overflow: TextOverflow.ellipsis,
          ),
        ],
      ),
    );
  }

  IconData _getIndexIcon(String type) {
    switch (type) {
      case '1':
        return LucideIcons.footprints;
      case '2':
        return LucideIcons.car;
      case '3':
        return LucideIcons.shirt;
      case '5':
        return LucideIcons.droplets;
      case '6':
        return LucideIcons.sun;
      case '7':
        return LucideIcons.heartPulse;
      case '8':
        return LucideIcons.umbrella;
      case '9':
        return LucideIcons.flower2;
      default:
        return LucideIcons.info;
    }
  }
}
