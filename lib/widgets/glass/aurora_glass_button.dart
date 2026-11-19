import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:liquid_glass_widgets/liquid_glass_widgets.dart';
import '../../core/theme/app_theme.dart';
import '../../providers/settings_provider.dart';

/// Aurora UI 的 Liquid Glass 文字按钮。
///
/// [expanded] 为 true 时会占满父级宽度；否则按内容自适应，
/// 也可以通过 [width] 指定固定宽度。
///
/// 用户关闭 Liquid Glass 后改为普通的半透明圆角按钮，
/// 尺寸和布局保持不变。
class AuroraGlassButton extends ConsumerWidget {
  /// 按钮文字
  final String label;

  /// 点击回调，为 null 时禁用按钮
  final VoidCallback? onPressed;

  /// 可选图标
  final IconData? icon;

  /// 是否占满父级宽度
  final bool expanded;

  /// 固定宽度（仅非 expanded 时生效）
  final double? width;

  /// 按钮高度
  final double height;

  /// 玻璃渲染质量
  final GlassQuality quality;

  const AuroraGlassButton({
    super.key,
    required this.label,
    required this.onPressed,
    this.icon,
    this.expanded = false,
    this.width,
    this.height = 48,
    this.quality = GlassQuality.premium,
  });

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final colorScheme = Theme.of(context).colorScheme;
    final glassEnabled = ref.watch(
      settingsProvider.select((settings) => settings.liquidGlassEnabled),
    );

    final content = Padding(
      padding: const EdgeInsets.symmetric(horizontal: 20),
      child: Row(
        mainAxisSize: expanded ? MainAxisSize.max : MainAxisSize.min,
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          if (icon != null) ...[
            Icon(icon, size: 18, color: colorScheme.onSurface),
            const SizedBox(width: 8),
          ],
          Text(
            label,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: Theme.of(context).textTheme.labelLarge?.copyWith(
              color: colorScheme.onSurface,
              fontWeight: FontWeight.w600,
            ),
          ),
        ],
      ),
    );

    if (!glassEnabled) {
      final tokens = context.uiTokens;
      return SizedBox(
        width: expanded ? double.infinity : width,
        height: height,
        child: TextButton(
          onPressed: onPressed,
          style: TextButton.styleFrom(
            backgroundColor: tokens.cardBackground,
            foregroundColor: colorScheme.onSurface,
            padding: EdgeInsets.zero,
            minimumSize: Size.zero,
            tapTargetSize: MaterialTapTargetSize.shrinkWrap,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(12),
              side: BorderSide(color: tokens.cardBorder),
            ),
          ),
          child: content,
        ),
      );
    }

    final hasGlassScope = LiquidGlassScope.of(context) != null;

    final button = GlassButton.custom(
      onTap: onPressed ?? () {},
      enabled: onPressed != null,
      width: width,
      height: height,
      shape: const LiquidRoundedSuperellipse(borderRadius: 12),
      quality: quality,
      useOwnLayer: !hasGlassScope,
      child: content,
    );

    if (expanded) {
      return SizedBox(width: double.infinity, child: button);
    }
    return button;
  }
}
