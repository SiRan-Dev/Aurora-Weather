import 'dart:io';

/// 当前系统版本是否不低于 [major].[minor]。
///
/// iOS 的 [Platform.operatingSystemVersion] 形如
/// `Version 17.4.1 (Build 21E236)`，解析失败时返回 false。
bool isOsVersionAtLeast(int major, int minor) {
  final match = RegExp(
    r'Version (\d+)\.(\d+)',
  ).firstMatch(Platform.operatingSystemVersion);
  if (match == null) return false;

  final currentMajor = int.tryParse(match.group(1)!) ?? 0;
  final currentMinor = int.tryParse(match.group(2)!) ?? 0;
  return currentMajor > major ||
      (currentMajor == major && currentMinor >= minor);
}
