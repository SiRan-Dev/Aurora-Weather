import 'dart:async';
import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../app_localizations.dart';
import '../models/weather_models.dart';
import '../services/qweather_service.dart';
import '../services/caiyun_service.dart';
import '../services/notification_service.dart';
import '../services/live_update_diagnostics_service.dart';
import 'city_provider.dart';
import 'settings_provider.dart';

/// 天气加载状态枚举
///
/// - initial: 初始状态
/// - loading: 加载中
/// - loaded: 加载完成
/// - error: 加载失败
enum WeatherLoadingState { initial, loading, loaded, error }

/// 天气状态类
///
/// 管理天气相关的所有状态数据，包括核心天气数据、空气质量和分钟级降雨预报
class WeatherState {
  /// 加载状态
  final WeatherLoadingState loadingState;

  /// 核心天气数据
  final WeatherData? weatherData;

  /// 空气质量数据
  final AirQuality? airQuality;

  /// 分钟级降雨预报
  final CaiyunMinuteRain? minuteRain;

  /// 生活指数数据
  final List<WeatherIndices>? weatherIndices;

  /// 错误信息
  final String? errorMessage;

  /// 构造函数
  const WeatherState({
    this.loadingState = WeatherLoadingState.initial,
    this.weatherData,
    this.airQuality,
    this.minuteRain,
    this.weatherIndices,
    this.errorMessage,
  });

  /// 复制并更新状态
  ///
  /// [loadingState]: 新的加载状态
  /// [weatherData]: 新的天气数据
  /// [airQuality]: 新的空气质量数据
  /// [minuteRain]: 新的分钟级降雨预报
  /// [weatherIndices]: 新的生活指数数据
  /// [errorMessage]: 新的错误信息
  /// [clearError]: 是否清除错误信息
  /// [clearWeather]: 是否清除天气数据
  WeatherState copyWith({
    WeatherLoadingState? loadingState,
    WeatherData? weatherData,
    AirQuality? airQuality,
    CaiyunMinuteRain? minuteRain,
    List<WeatherIndices>? weatherIndices,
    String? errorMessage,
    bool clearError = false,
    bool clearWeather = false,
  }) {
    return WeatherState(
      loadingState: loadingState ?? this.loadingState,
      weatherData: clearWeather ? null : (weatherData ?? this.weatherData),
      airQuality: clearWeather ? null : (airQuality ?? this.airQuality),
      minuteRain: clearWeather ? null : (minuteRain ?? this.minuteRain),
      weatherIndices: clearWeather
          ? null
          : (weatherIndices ?? this.weatherIndices),
      errorMessage: clearError ? null : (errorMessage ?? this.errorMessage),
    );
  }

  /// 是否正在加载
  bool get isLoading => loadingState == WeatherLoadingState.loading;

  /// 是否有数据
  bool get hasData => weatherData != null;

  /// 是否有错误
  bool get hasError => errorMessage != null;
}

/// 天气状态管理类
///
/// 负责处理天气数据的加载、刷新和通知等操作
class WeatherNotifier extends StateNotifier<WeatherState> {
  /// 和风天气服务
  final QWeatherService _qweatherService;

  /// 彩云天气服务
  final CaiyunWeatherService _caiyunService;

  /// Riverpod 引用
  final Ref _ref;

  /// 已显示的预警ID集合，用于避免重复显示通知
  final Set<String> _shownAlertIds = {};

  /// 加载请求计数器，用于防止并发加载时旧请求覆盖新结果
  int _loadRequestId = 0;

  /// 正在加载的位置ID，用于合并同一位置的重复请求
  String? _loadingLocationId;

  /// 上次缓存清理时间
  DateTime _lastCacheCleanupTime = DateTime.fromMillisecondsSinceEpoch(0);

  /// 构造函数
  WeatherNotifier(this._ref, this._qweatherService, this._caiyunService)
    : super(const WeatherState());

  /// 加载指定位置的天气数据
  ///
  /// [location]: 位置信息
  /// [force]: 为 true 时即使同一位置正在加载也重新发起请求
  Future<void> loadWeather(Location location, {bool force = false}) async {
    // 同一位置的请求仍在进行中时直接复用，避免首屏加载与监听器重复触发
    if (!force &&
        state.loadingState == WeatherLoadingState.loading &&
        _loadingLocationId == location.id) {
      return;
    }

    final requestId = ++_loadRequestId;
    _loadingLocationId = location.id;

    // 如果已有请求正在进行，仅更新 loading 状态（不清理已有数据）
    state = state.copyWith(
      loadingState: WeatherLoadingState.loading,
      clearError: true,
    );

    try {
      // 1. 获取核心天气数据 (和风天气)
      final weatherData = await _qweatherService.getFullWeatherData(
        location.id,
        location,
      );

      // 并发保护：如果已有更新的请求，跳过本次结果
      if (requestId != _loadRequestId) return;

      // 核心天气先发布，辅助数据不再阻塞首屏展示
      state = WeatherState(
        loadingState: WeatherLoadingState.loaded,
        weatherData: weatherData,
      );
      _loadingLocationId = null;

      // 自动持久化缓存数据，供定时播报回退使用
      _saveWeatherCache(location.id, weatherData);

      // 2. 辅助数据并发获取，各自限制 5 秒，失败不影响核心数据
      final (airQuality, minuteRain, weatherIndices) = await (
        _loadOptional(_qweatherService.getAirQuality(location.id)),
        _loadOptional(_caiyunService.getMinuteRain(location.lat, location.lon)),
        _loadOptional(_qweatherService.getWeatherIndices(location.id)),
      ).wait;

      // 并发保护：辅助数据获取期间可能已发起新请求
      if (requestId != _loadRequestId) return;

      state = state.copyWith(
        airQuality: airQuality,
        minuteRain: minuteRain,
        weatherIndices: weatherIndices,
      );

      // 清理孤儿数据（限制频率：最多每小时一次）
      final now = DateTime.now();
      if (now.difference(_lastCacheCleanupTime).inHours >= 1) {
        _lastCacheCleanupTime = now;
        _cleanupWeatherCache();
      }

      // 检查并发送天气预警通知
      await _checkAndSendAlertNotifications(weatherData.alerts);

      // 同步 Android 实时更新通知
      await syncAndroidLiveUpdateNotificationWithSettings(
        scene: 'weather_load',
      );
    } catch (e) {
      // 并发保护：仅更新当前请求的错误状态
      if (requestId != _loadRequestId) return;

      _loadingLocationId = null;

      // 更新状态为错误
      state = state.copyWith(
        loadingState: WeatherLoadingState.error,
        errorMessage: e.toString(),
      );
    }
  }

  /// 加载可选的辅助天气数据
  ///
  /// 超时或失败时返回 null，不阻塞核心天气展示。
  Future<T?> _loadOptional<T>(Future<T> future) async {
    try {
      return await future.timeout(const Duration(seconds: 5));
    } catch (e) {
      debugPrint('加载辅助天气数据失败: $e');
      return null;
    }
  }

  /// 更新天气数据中记录的位置信息（例如反向地理编码补齐名称）
  ///
  /// 不会重新请求天气接口。
  void updateLocationInfo(Location location) {
    final data = state.weatherData;
    if (data == null || data.location.id != location.id) return;
    state = state.copyWith(
      weatherData: data.copyWith(location: location),
    );
  }

  /// 检查并发送天气预警通知
  ///
  /// [alerts]: 天气预警列表
  Future<void> _checkAndSendAlertNotifications(
    List<WeatherAlert> alerts,
  ) async {
    final settings = _ref.read(settingsProvider);
    if (!settings.notificationsEnabled) return;

    final hasPermission = await notificationServiceProvider
        .checkNotificationPermission();
    if (!hasPermission) return;

    for (final alert in alerts) {
      if (!_shownAlertIds.contains(alert.id)) {
        await notificationServiceProvider.showWeatherWarningAlert(
          alertType: alert.typeName,
          severity: _getSeverityText(alert.level),
          description: _truncateText(alert.text, 100),
        );
        _shownAlertIds.add(alert.id);
      }
    }
  }

  /// 根据当前设置与天气状态，同步 Android 实时更新通知
  Future<void> syncAndroidLiveUpdateNotificationWithSettings({
    String scene = 'weather_sync',
  }) async {
    final settings = _ref.read(settingsProvider);
    bool? isAndroid;
    bool? hasWeatherData;
    bool? isSupported;
    bool? hasNotificationPermission;
    bool? hasPromotedPermission;
    bool? promotableCharacteristics;
    String? titlePreview;

    if (!settings.androidLiveUpdateNotificationEnabled) {
      await notificationServiceProvider.cancelAndroidLiveWeatherUpdate();
      liveUpdateDiagnosticsService.record(
        scene: scene,
        success: false,
        code: 'SETTING_DISABLED',
        message: AppLocalizations.tr('实时更新开关未开启'),
        settingEnabled: false,
      );
      return;
    }

    isAndroid = !kIsWeb && defaultTargetPlatform == TargetPlatform.android;
    if (!isAndroid) {
      liveUpdateDiagnosticsService.record(
        scene: scene,
        success: false,
        code: 'NON_ANDROID_PLATFORM',
        message: AppLocalizations.tr('当前平台不是 Android'),
        settingEnabled: true,
        isAndroid: false,
      );
      return;
    }

    final weatherData = state.weatherData;
    hasWeatherData = weatherData != null;
    if (weatherData == null) {
      liveUpdateDiagnosticsService.record(
        scene: scene,
        success: false,
        code: 'NO_WEATHER_DATA',
        message: AppLocalizations.tr('当前没有可用于实时更新的天气数据'),
        settingEnabled: true,
        isAndroid: isAndroid,
        hasWeatherData: false,
      );
      return;
    }

    titlePreview = '${weatherData.location.name} ${weatherData.current.temp}°';

    final supported = await notificationServiceProvider
        .isAndroidLiveUpdateSupported();
    isSupported = supported;
    if (!supported) {
      liveUpdateDiagnosticsService.record(
        scene: scene,
        success: false,
        code: 'ANDROID_VERSION_UNSUPPORTED',
        message: AppLocalizations.tr('当前系统不支持实时更新通知（需 Android 16+）'),
        settingEnabled: true,
        isAndroid: isAndroid,
        hasWeatherData: hasWeatherData,
        isSupported: false,
        titlePreview: titlePreview,
      );
      return;
    }

    final canPostPromoted = await notificationServiceProvider
        .canPostPromotedNotifications();
    hasPromotedPermission = canPostPromoted;
    if (!canPostPromoted) {
      await notificationServiceProvider.cancelAndroidLiveWeatherUpdate();
      liveUpdateDiagnosticsService.record(
        scene: scene,
        success: false,
        code: 'PROMOTED_PERMISSION_DENIED',
        message: AppLocalizations.tr('系统未允许应用发布 Promoted 实时更新通知'),
        settingEnabled: true,
        isAndroid: isAndroid,
        hasWeatherData: hasWeatherData,
        isSupported: isSupported,
        promotedPermission: false,
        titlePreview: titlePreview,
      );
      return;
    }

    final hasPermission = await notificationServiceProvider
        .checkNotificationPermission();
    hasNotificationPermission = hasPermission;
    if (!hasPermission) {
      liveUpdateDiagnosticsService.record(
        scene: scene,
        success: false,
        code: 'NOTIFICATION_PERMISSION_DENIED',
        message: AppLocalizations.tr('未授予通知权限'),
        settingEnabled: true,
        isAndroid: isAndroid,
        hasWeatherData: hasWeatherData,
        isSupported: isSupported,
        notificationPermission: false,
        promotedPermission: hasPromotedPermission,
        titlePreview: titlePreview,
      );
      return;
    }

    final content = AppLocalizations.tr(
      '{text} · 体感{feelsLike}° · {time} 更新',
      args: {
        'text': AppLocalizations.tr(weatherData.current.text),
        'feelsLike': weatherData.current.feelsLike,
        'time': _formatTime(weatherData.lastUpdated),
      },
    );

    final result = await notificationServiceProvider
        .showAndroidLiveWeatherUpdateDetailed(
          title: titlePreview,
          content: content,
        );

    promotableCharacteristics = result.code == 'NOT_PROMOTABLE_CHARACTERISTICS'
        ? false
        : (result.success ? true : null);
    liveUpdateDiagnosticsService.record(
      scene: scene,
      success: result.success,
      code: result.code,
      message: result.message,
      settingEnabled: true,
      isAndroid: isAndroid,
      hasWeatherData: hasWeatherData,
      isSupported: isSupported,
      notificationPermission: hasNotificationPermission,
      promotedPermission: hasPromotedPermission,
      promotableCharacteristics: promotableCharacteristics,
      titlePreview: titlePreview,
    );
  }

  /// 获取预警级别文本
  ///
  /// [level]: 预警级别
  String _getSeverityText(String level) {
    switch (level) {
      case '红色':
        return AppLocalizations.tr('🔴 红色预警 - 极端天气');
      case '橙色':
        return AppLocalizations.tr('🟠 橙色预警 - 严重天气');
      case '黄色':
        return AppLocalizations.tr('🟡 黄色预警 - 较重天气');
      case '蓝色':
        return AppLocalizations.tr('🔵 蓝色预警 - 一般天气');
      default:
        return AppLocalizations.tr(level);
    }
  }

  /// 截断文本
  ///
  /// [text]: 原始文本
  /// [maxLength]: 最大长度
  String _truncateText(String text, int maxLength) {
    if (text.length <= maxLength) return text;
    return '${text.substring(0, maxLength)}...';
  }

  String _formatTime(DateTime dateTime) {
    final hour = dateTime.hour.toString().padLeft(2, '0');
    final minute = dateTime.minute.toString().padLeft(2, '0');
    return '$hour:$minute';
  }

  /// 刷新天气数据
  Future<void> refresh() async {
    final location = _ref.read(defaultCityProvider);
    if (location != null) {
      await loadWeather(location, force: true);
    }
  }

  /// 持久化天气数据缓存
  Future<void> _saveWeatherCache(String locationId, WeatherData data) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final key = 'weather_cache_$locationId';
      await prefs.setString(key, jsonEncode(data.toJson()));
      debugPrint('[WeatherCache] Saved cache for $locationId');
    } catch (e) {
      debugPrint('[WeatherCache] Save failed: $e');
    }
  }

  /// 清理已删除城市的孤儿缓存
  Future<void> _cleanupWeatherCache() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final keys = prefs.getKeys();

      // 获取当前所有保存的城市ID
      final cityStore = await _ref.read(cityRepositoryProvider).loadStore();
      final currentCityIds = cityStore.cities.map((city) => city.id).toSet();

      // 扫描并删除孤儿缓存
      for (final key in keys) {
        if (key.startsWith('weather_cache_')) {
          final cityId = key.replaceFirst('weather_cache_', '');
          if (!currentCityIds.contains(cityId)) {
            await prefs.remove(key);
            debugPrint('[WeatherCache] Cleaned up orphaned cache: $key');
          }
        }
      }
    } catch (e) {
      debugPrint('[WeatherCache] Cleanup failed: $e');
    }
  }

  /// 清除错误信息
  void clearError() {
    state = state.copyWith(clearError: true);
  }
}

/// 天气状态Provider
///
/// 提供全局天气状态管理
final weatherProvider = StateNotifierProvider<WeatherNotifier, WeatherState>((
  ref,
) {
  return WeatherNotifier(
    ref,
    ref.watch(qweatherServiceProvider),
    ref.watch(caiyunWeatherServiceProvider),
  );
});

/// 城市天气数据Provider
///
/// 为指定城市提供天气数据
/// [Location]: 城市位置信息
final weatherForCityProvider = FutureProvider.family<WeatherData?, Location>((
  ref,
  location,
) async {
  final service = ref.watch(qweatherServiceProvider);
  try {
    return await service.getFullWeatherData(location.id, location);
  } catch (_) {
    return null;
  }
});
