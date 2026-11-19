import 'package:flutter/material.dart';

/// 占满视口的居中状态视图。
///
/// 统一承载加载中 / 定位中 / 定位失败 / 加载失败 / 空状态页，
/// 消除各页面重复的「图标 + 标题 + 副文案 + 操作」骨架。
///
/// 需要右上角按钮（例如空状态的「导航」）时通过 [actions] 传入，
/// 由 [onActionPressed] 等回调触发的按钮会与内容一同布局。
class FullScreenStatus extends StatelessWidget {
  /// 主图标
  final IconData icon;

  /// 图标颜色
  final Color iconColor;

  /// 标题文字
  final String title;

  /// 标题颜色
  final Color titleColor;

  /// 副文案
  final String? message;

  /// 居中的操作按钮
  final List<Widget> actions;

  const FullScreenStatus({
    super.key,
    required this.icon,
    required this.iconColor,
    required this.title,
    required this.titleColor,
    this.message,
    this.actions = const [],
  });

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;

    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(icon, size: 64, color: iconColor),
            const SizedBox(height: 16),
            Text(
              title,
              style: Theme.of(context).textTheme.titleMedium?.copyWith(
                color: titleColor,
                fontWeight: FontWeight.bold,
              ),
            ),
            if (message != null) ...[
              const SizedBox(height: 8),
              Text(
                message!,
                textAlign: TextAlign.center,
                style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                  color: colorScheme.onSurfaceVariant,
                ),
              ),
            ],
            if (actions.isNotEmpty) ...[
              const SizedBox(height: 24),
              Wrap(
                spacing: 12,
                runSpacing: 12,
                alignment: WrapAlignment.center,
                children: actions,
              ),
            ],
          ],
        ),
      ),
    );
  }
}