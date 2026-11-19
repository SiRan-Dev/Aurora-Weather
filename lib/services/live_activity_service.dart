import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';

import '../core/platform/platform_capabilities.dart';
import '../models/weather_models.dart';

/// iOS 锁屏实时活动（Live Activity / 灵动岛）服务。
///
/// 通过 MethodChannel 调用原生 ActivityKit 桥接；在非 iOS 平台或
/// iOS 16.1 以下静默降级（所有调用直接返回）。
class LiveActivityService {
  static const MethodChannel _channel = MethodChannel(
    'com.sirandev.auroraweather/live_activity',
  );

  /// 原生侧是否支持并允许实时活动（系统设置未关闭）
  bool _supported = false;

  Future<bool>? _ready;

  /// 初始化并检查系统是否支持实时活动。
  Future<bool> ensureReady() {
    return _ready ??= _initialize();
  }

  Future<bool> _initialize() async {
    if (!supportsLiveActivities) {
      _supported = false;
      return false;
    }

    try {
      _supported = await _channel.invokeMethod<bool>('isSupported') ?? false;
    } on PlatformException catch (e) {
      debugPrint('实时活动检查失败: ${e.message}');
      _supported = false;
    } on MissingPluginException {
      // 原生未注册（例如旧版本安装包）
      _supported = false;
    }
    return _supported;
  }

  /// 创建活动；已存在时原生侧会转为更新。
  Future<void> start(Map<String, dynamic> data) => _invoke('start', data);

  /// 更新活动数据。
  Future<void> update(Map<String, dynamic> data) => _invoke('update', data);

  /// 结束并立即移除活动。
  Future<void> end() => _invoke('end', null);

  Future<void> _invoke(String method, Map<String, dynamic>? args) async {
    if (!await ensureReady()) return;

    try {
      await _channel.invokeMethod<void>(method, args);
    } on PlatformException catch (e) {
      debugPrint('实时活动 $method 失败: ${e.message}');
    } on MissingPluginException {
      // 原生未注册，忽略
    }
  }

  /// 从天气数据构建实时活动载荷。
  static Map<String, dynamic> payloadFromWeather(WeatherData weather) {
    final daily = weather.daily.isNotEmpty ? weather.daily.first : null;
    return {
      'city': weather.location.name,
      'temp': weather.current.temp,
      'feelsLike': weather.current.feelsLike,
      'text': weather.current.text,
      'icon': weather.current.icon,
      'tempMax': daily?.tempMax ?? '',
      'tempMin': daily?.tempMin ?? '',
      'updatedAt': weather.lastUpdated.millisecondsSinceEpoch ~/ 1000,
    };
  }
}

/// 全局实时活动服务实例（与 notificationServiceProvider 的写法保持一致）。
final LiveActivityService liveActivityService = LiveActivityService();
