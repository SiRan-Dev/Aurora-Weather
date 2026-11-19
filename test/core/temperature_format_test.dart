import 'package:flutter_test/flutter_test.dart';
import 'package:pureweather/core/constants/app_constants.dart';

void main() {
  group('WeatherCode.formatTemp', () {
    test('摄氏输出整数值 + °C', () {
      expect(WeatherCode.formatTemp('17', toFahrenheit: false), '17°C');
      expect(WeatherCode.formatTemp('-5', toFahrenheit: false), '-5°C');
    });

    test('华氏输出转换后的整数值 + °F', () {
      expect(WeatherCode.formatTemp('0', toFahrenheit: true), '32°F');
      expect(WeatherCode.formatTemp('25', toFahrenheit: true), '77°F');
      expect(WeatherCode.formatTemp('-40', toFahrenheit: true), '-40°F');
    });

    test('非数字输入原样返回（带单位）', () {
      // 解析失败时 convertTemperature 返回原字符串，formatTemp 仍补上单位。
      expect(WeatherCode.formatTemp('--', toFahrenheit: false), '--°C');
    });
  });

  group('WeatherCode.isFahrenheit', () {
    test('收口温度单位判断', () {
      expect(WeatherCode.isFahrenheit('fahrenheit'), isTrue);
      expect(WeatherCode.isFahrenheit('celsius'), isFalse);
      expect(WeatherCode.isFahrenheit(''), isFalse);
    });
  });
}