import 'package:flutter_dotenv/flutter_dotenv.dart';

import '_env_io.dart' if (dart.library.html) '_env_web.dart' as env;

/// API configuration.
///
/// Lookup order (high to low priority):
/// 1) --dart-define
/// 2) Process environment variables (non-web only)
/// 3) .env (flutter_dotenv)
class ApiConfig {
  static String _fromEnv(String key) {
    try {
      return env.envVar(key);
    } catch (_) {
      return '';
    }
  }

  static const _defaultQWeatherBaseUrl = 'https://devapi.qweather.com/v7';
  static const _defaultCaiyunBaseUrl = 'https://api.caiyunapp.com/v2.6';

  /// Accepts a full base URL or the bare API host shown in the console
  /// (for example `xxxx.qweatherapi.com`) and fills in the missing scheme
  /// and default API path.
  static String _normalizeBaseUrl(
    String raw,
    String defaultPath,
    String fallback,
  ) {
    var value = raw.trim();
    if (value.isEmpty) return fallback;
    if (!value.contains('://')) value = 'https://$value';
    value = value.replaceFirst(RegExp(r'/+$'), '');
    final uri = Uri.tryParse(value);
    if (uri == null || uri.host.isEmpty) return fallback;
    if (uri.path.isEmpty) value = '$value$defaultPath';
    return value;
  }

  static String get qweatherApiKey {
    const fromDefine = String.fromEnvironment(
      'QWEATHER_API_KEY',
      defaultValue: '',
    );
    if (fromDefine.isNotEmpty) return fromDefine;
    return _fromEnv('QWEATHER_API_KEY').isNotEmpty
        ? _fromEnv('QWEATHER_API_KEY')
        : dotenv.env['QWEATHER_API_KEY'] ?? '';
  }

  static String get qweatherBaseUrl {
    const fromDefine = String.fromEnvironment(
      'QWEATHER_BASE_URL',
      defaultValue: '',
    );
    if (fromDefine.isNotEmpty) {
      return _normalizeBaseUrl(
        fromDefine,
        '/v7',
        _defaultQWeatherBaseUrl,
      );
    }
    final fromDotenv = dotenv.env['QWEATHER_BASE_URL'] ?? '';
    return fromDotenv.isNotEmpty
        ? _normalizeBaseUrl(fromDotenv, '/v7', _defaultQWeatherBaseUrl)
        : _defaultQWeatherBaseUrl;
  }

  static String get caiyunApiKey {
    const fromDefine = String.fromEnvironment(
      'CAIYUN_API_KEY',
      defaultValue: '',
    );
    if (fromDefine.isNotEmpty) return fromDefine;
    return _fromEnv('CAIYUN_API_KEY').isNotEmpty
        ? _fromEnv('CAIYUN_API_KEY')
        : dotenv.env['CAIYUN_API_KEY'] ?? '';
  }

  static String get caiyunBaseUrl {
    const fromDefine = String.fromEnvironment(
      'CAIYUN_BASE_URL',
      defaultValue: '',
    );
    if (fromDefine.isNotEmpty) {
      return _normalizeBaseUrl(
        fromDefine,
        '/v2.6',
        _defaultCaiyunBaseUrl,
      );
    }
    final fromDotenv = dotenv.env['CAIYUN_BASE_URL'] ?? '';
    return fromDotenv.isNotEmpty
        ? _normalizeBaseUrl(fromDotenv, '/v2.6', _defaultCaiyunBaseUrl)
        : _defaultCaiyunBaseUrl;
  }

  static String get amapApiKey {
    const fromDefine = String.fromEnvironment('AMAP_API_KEY', defaultValue: '');
    if (fromDefine.isNotEmpty) return fromDefine;
    return _fromEnv('AMAP_API_KEY').isNotEmpty
        ? _fromEnv('AMAP_API_KEY')
        : dotenv.env['AMAP_API_KEY'] ?? '';
  }

  static String get amapWebKey {
    const fromDefine = String.fromEnvironment('AMAP_WEB_KEY', defaultValue: '');
    if (fromDefine.isNotEmpty) return fromDefine;
    return _fromEnv('AMAP_WEB_KEY').isNotEmpty
        ? _fromEnv('AMAP_WEB_KEY')
        : dotenv.env['AMAP_WEB_KEY'] ?? '';
  }

  static bool get isConfigured {
    return qweatherApiKey.isNotEmpty && amapApiKey.isNotEmpty;
  }
}
