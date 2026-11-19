import 'package:flutter/foundation.dart';

import 'device_os.dart';

/// 系统通知能力（天气预警推送、定时播报、实时更新通知）。
///
/// Android / iOS / macOS / Linux 支持系统通知；Web 和 Windows 没有
/// 对应实现，相关设置项应直接隐藏。
bool get supportsSystemNotifications =>
    !kIsWeb && defaultTargetPlatform != TargetPlatform.windows;

/// 预测式返回手势仅在 Android 14+ 生效，其他平台不显示该设置。
bool get supportsPredictiveBack =>
    !kIsWeb && defaultTargetPlatform == TargetPlatform.android;

/// iOS 锁屏实时活动（Live Activity / 灵动岛）需要 iOS 16.1+。
bool get supportsLiveActivities =>
    !kIsWeb &&
    defaultTargetPlatform == TargetPlatform.iOS &&
    isOsVersionAtLeast(16, 1);
