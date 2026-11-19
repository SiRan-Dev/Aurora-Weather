import 'package:flutter/material.dart';

/// Aurora 卡片统一的标题栏：图标 + 文案。
///
/// 六个天气卡片（小时/日/空气/指数/详情）目前各自重复一段
/// `Row[Icon, SizedBox(8), Text]`，抽成统一组件便于统一字号与间距。
class GlassCardHeader extends StatelessWidget {
  /// 左侧图标
  final IconData icon;

  /// 标题文案
  final String title;

  /// 图标尺寸
  final double iconSize;

  /// 标题字号是否加重（用于详情卡）
  final bool emphasized;

  const GlassCardHeader({
    super.key,
    required this.icon,
    required this.title,
    this.iconSize = 20,
    this.emphasized = false,
  });

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Icon(
          icon,
          size: iconSize,
          color: Theme.of(context).colorScheme.primary,
        ),
        const SizedBox(width: 8),
        Text(
          title,
          style: Theme.of(context).textTheme.titleMedium?.copyWith(
            fontWeight: emphasized ? FontWeight.w600 : FontWeight.w500,
          ),
        ),
      ],
    );
  }
}