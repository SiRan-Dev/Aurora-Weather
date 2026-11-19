import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:liquid_glass_widgets/liquid_glass_widgets.dart';
import '../../core/theme/app_theme.dart';
import '../../providers/settings_provider.dart';

/// Aurora UI 的 Liquid Glass 图标按钮。
///
/// 用户关闭 Liquid Glass 后改为普通的圆形半透明按钮，
/// 尺寸、图标大小和提示行为保持不变。
class AuroraGlassIconButton extends ConsumerWidget {
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
  Widget build(BuildContext context, WidgetRef ref) {
    final glassEnabled = ref.watch(
      settingsProvider.select((settings) => settings.liquidGlassEnabled),
    );

    if (!glassEnabled) {
      final tokens = context.uiTokens;
      return Container(
        width: size,
        height: size,
        clipBehavior: Clip.antiAlias,
        decoration: BoxDecoration(
          color: tokens.cardBackground,
          shape: BoxShape.circle,
          border: Border.all(color: tokens.cardBorder),
        ),
        child: IconButton(
          icon: Icon(icon, size: iconSize, color: color),
          onPressed: onPressed,
          tooltip: tooltip,
          iconSize: iconSize,
          padding: EdgeInsets.zero,
          constraints: BoxConstraints.tightFor(width: size, height: size),
        ),
      );
    }

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
