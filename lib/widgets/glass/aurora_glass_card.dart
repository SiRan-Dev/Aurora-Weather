import 'package:flutter/material.dart';
import 'package:liquid_glass_widgets/liquid_glass_widgets.dart';

/// Aurora UI 的 Liquid Glass 卡片。
///
/// 在 [GlassPage] 内部使用分组渲染以共享玻璃层；在弹窗、对话框等
/// 独立路由中使用自绘玻璃层，避免缺少祖先玻璃层导致渲染失败。
class AuroraGlassCard extends StatelessWidget {
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
  Widget build(BuildContext context) {
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
