import 'package:flutter_test/flutter_test.dart';
import 'package:pureweather/providers/settings_provider.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  group('cardOrderToKey / cardTypeFromKey 往返', () {
    test('default order serializes to the legacy string keys', () {
      expect(
        kDefaultWeatherCardOrder.map(cardOrderToKey).toList(),
        ['hourly', 'daily', 'airQuality', 'details', 'indices'],
      );
    });

    test('every enum value round-trips through storage keys', () {
      for (final type in WeatherCardType.values) {
        expect(cardTypeFromKey(cardOrderToKey(type)), type);
      }
    });

    test('unknown key maps to null (defensive against corrupted prefs)', () {
      expect(cardTypeFromKey('typo-card'), isNull);
      expect(cardTypeFromKey(null), isNull);
      expect(cardTypeFromKey(''), isNull);
    });

    test('all enum values have distinct storage keys', () {
      final keys = WeatherCardType.values.map(cardOrderToKey).toSet();
      expect(keys.length, WeatherCardType.values.length);
    });
  });

  group('SettingsNotifier 卡片顺序', () {
    test('legacy string prefs are migrated into the enum order', () async {
      // 模拟老版本只存了部分、顺序打乱的字符串 key。
      SharedPreferences.setMockInitialValues({
        'weather_card_order': ['airQuality', 'hourly'],
      });
      final notifier = SettingsNotifier();
      await Future<void>.delayed(Duration.zero); // 等待 _loadSettings() 完成

      final order = notifier.state.weatherCardOrder;
      // 已保存的卡片保持原顺序
      expect(order.sublist(0, 2), [
        WeatherCardType.airQuality,
        WeatherCardType.hourly,
      ]);
      // 缺失的卡片按默认顺序补全在后面，且不重复。
      expect(
        order.sublist(2),
        [WeatherCardType.daily, WeatherCardType.details, WeatherCardType.indices],
      );
      expect(order.toSet().length, order.length);
      notifier.dispose();
    });

    test('setWeatherCardOrder normalizes duplicates and appends missing', () async {
      SharedPreferences.setMockInitialValues({
        'weather_card_order': kDefaultWeatherCardOrder
            .map(cardOrderToKey)
            .toList(),
      });
      final notifier = SettingsNotifier();
      await Future<void>.delayed(Duration.zero);

      await notifier.setWeatherCardOrder([
        WeatherCardType.details,
        WeatherCardType.hourly,
        WeatherCardType.hourly, // 重复项去重
      ]);

      expect(notifier.state.weatherCardOrder, [
        WeatherCardType.details,
        WeatherCardType.hourly,
        // 补充缺失
        WeatherCardType.daily,
        WeatherCardType.airQuality,
        WeatherCardType.indices,
      ]);
      notifier.dispose();
    });

    test('setting the full default order persists it back through keys', () async {
      SharedPreferences.setMockInitialValues({
        'weather_card_order': ['daily', 'hourly'],
      });
      final notifier = SettingsNotifier();
      await Future<void>.delayed(Duration.zero);

      await notifier.setWeatherCardOrder(List.from(kDefaultWeatherCardOrder));

      final prefs = await SharedPreferences.getInstance();
      expect(
        prefs.getStringList('weather_card_order'),
        ['hourly', 'daily', 'airQuality', 'details', 'indices'],
      );
      expect(notifier.state.weatherCardOrder, kDefaultWeatherCardOrder);
      notifier.dispose();
    });
  });
}