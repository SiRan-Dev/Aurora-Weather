import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:liquid_glass_widgets/liquid_glass_widgets.dart';
import '../../core/theme/app_theme.dart';
import '../../providers/settings_provider.dart';

/// Aurora UI 的 Liquid Glass 卡片。
///
/// 在 [GlassPage] 内部使用分组渲染以共享玻璃层；在弹窗、对话框等
/// 独立路由中使用自绘玻璃层，避免缺少祖先玻璃层导致渲染失败。
///
/// 用户可以在设置中关闭 Liquid Glass；关闭后改为普通半透明表面，
/// 不进行任何背景采样或着色器渲染（对性能较弱的平台更友好）。
class AuroraGlassCard extends ConsumerWidget {
  /// 卡片内容
  final Widget child;

  /// 内容内边距
  final EdgeInsetsGeometry padding;

  /// 卡片外边距
  final EdgeInsetsGeometry? margin;

  /// 圆角半径
  final double borderRadius;

  /// 玻璃渲染质量
  final GlassQuality quality;

  const AuroraGlassCard({
    super.key,
    required this.child,
    this.padding = const EdgeInsets.all(16),
    this.margin,
    this.borderRadius = 16,
    this.quality = GlassQuality.standard,
  });

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final glassEnabled = ref.watch(
      settingsProvider.select((settings) => settings.liquidGlassEnabled),
    );

    if (!glassEnabled) {
      final tokens = context.uiTokens;
      return Container(
        margin: margin,
        padding: padding,
        clipBehavior: Clip.antiAlias,
        decoration: BoxDecoration(
          color: tokens.cardBackground,
          borderRadius: BorderRadius.circular(borderRadius),
          border: Border.all(color: tokens.cardBorder),
        ),
        child: child,
      );
    }

    final hasGlassScope = LiquidGlassScope.of(context) != null;

    return GlassContainer.card(
      padding: padding,
      margin: margin,
      shape: LiquidRoundedSuperellipse(borderRadius: borderRadius),
      clipBehavior: Clip.antiAlias,
      quality: quality,
      useOwnLayer: !hasGlassScope,
      child: child,
    );
  }
}
