import 'package:flutter/material.dart';
import 'package:liquid_glass_widgets/liquid_glass_widgets.dart';

/// Aurora UI 的 Liquid Glass 图标按钮。
class AuroraGlassIconButton extends StatelessWidget {
  /// 图标
  final IconData icon;

  /// 点击回调，为 null 时禁用按钮
  final VoidCallback? onPressed;

  /// 无障碍/长按提示
  final String? tooltip;

  /// 按钮直径
  final double size;

  /// 图标尺寸
  final double? iconSize;

  /// 图标颜色
  final Color? color;

  /// 玻璃渲染质量
  final GlassQuality quality;

  /// 是否强制使用独立玻璃层。
  ///
  /// 页面级玻璃层默认以 standard 质量渲染，独立层才能让 premium
  /// 反射/高光完整生效，用于需要突出质感的独立按钮。
  final bool preferOwnLayer;

  const AuroraGlassIconButton({
    super.key,
    required this.icon,
    required this.onPressed,
    this.tooltip,
    this.size = 40,
    this.iconSize,
    this.color,
    this.quality = GlassQuality.premium,
    this.preferOwnLayer = false,
  });

  @override
  Widget build(BuildContext context) {
    final hasGlassScope = LiquidGlassScope.of(context) != null;

    final button = GlassIconButton(
      icon: Icon(icon, size: iconSize, color: color),
      onPressed: onPressed,
      size: size,
      quality: quality,
      useOwnLayer: preferOwnLayer || !hasGlassScope,
      semanticLabel: tooltip,
    );

    if (tooltip == null) return button;
    return Tooltip(message: tooltip!, child: button);
  }
}
