// 跨平台获取系统版本号。
// Web 构建不能引入 dart:io，这里用条件导出在 Web 下退化为
// 永远返回 false 的桩实现。
export 'device_os_stub.dart' if (dart.library.io) 'device_os_io.dart';
