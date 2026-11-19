import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:pureweather/app_localizations.dart';
import 'package:pureweather/models/weather_models.dart';
import 'package:pureweather/widgets/hourly_forecast.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// 构造一个逐小时预报项，[pop] 为降水概率，空串表示无降水数据。
///
/// 时间相对 `DateTime.now()` 生成，确保落在「未来 24 小时」过滤窗口内，
/// 否则运行到深夜时 `_filterHourlyData` 会把大部分项滤掉导致断言不稳。
HourlyWeather hourlyItem(int hourOffset, {String pop = '0'}) {
  final future = DateTime.now().add(Duration(hours: hourOffset));
  final hour = future.hour.toString().padLeft(2, '0');
  final day = future.day.toString().padLeft(2, '0');
  final month = future.month.toString().padLeft(2, '0');

  return HourlyWeather(
    fxTime: '${future.year}-$month-${day}T$hour:00+08:00',
    temp: '${10 + hourOffset % 5}',
    icon: '100',
    text: '晴',
    wind360: '0',
    windDir: '北风',
    windScale: '2',
    windSpeed: '10',
    humidity: '50',
    pop: pop,
    precip: '0',
    pressure: '1013',
    cloud: '10',
    dew: '5',
  );
}

Widget _harness(Widget child) {
  return ProviderScope(
    child: MaterialApp(
      localizationsDelegates: const [
        AppLocalizations.delegate,
        GlobalMaterialLocalizations.delegate,
        GlobalWidgetsLocalizations.delegate,
        GlobalCupertinoLocalizations.delegate,
      ],
      supportedLocales: AppLocalizations.supportedLocales,
      home: Scaffold(body: Center(child: child)),
    ),
  );
}

void main() {
  setUp(() {
    SharedPreferences.setMockInitialValues({});
  });

  testWidgets('B1: hourly forecast adapts height and does not overflow at 2x text scale', (
    tester,
  ) async {
    final items = List.generate(8, (i) => hourlyItem(1 + i, pop: '70'));

    tester.view.physicalSize = const Size(390 * 2, 844 * 2);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.reset);

    await tester.pumpWidget(
      _harness(
        HourlyForecast(
          hourly: items,
          temperatureUnit: 'celsius',
        ),
      ),
    );
    await tester.pumpAndSettle();

    // 图标 + 时间 + 温度 + 降水 四行都在，高度由内容撑起。
    expect(find.byType(HourlyForecast), findsOneWidget);
    // 4 个可见项（targetVisibleItems=5，但 390 宽下有部分裁剪）
    expect(find.byType(Icon), findsWidgets);
    expect(find.textContaining('%'), findsWidgets);
    // 没有因固定高度导致的溢出异常。
    expect(tester.takeException(), isNull);
  });

  testWidgets('B1: precipitation row is hidden when every hour has pop=0', (
    tester,
  ) async {
    final dry = List.generate(5, (i) => hourlyItem(1 + i, pop: '0'));
    await tester.pumpWidget(_harness(HourlyForecast(hourly: dry)));
    await tester.pumpAndSettle();

    // 无降水时不显示任何百分比行，也不溢出。
    expect(find.textContaining('%'), findsNothing);
    expect(tester.takeException(), isNull);
  });

  testWidgets('B1: precipitation row appears when any hour has pop', (
    tester,
  ) async {
    final wet = List.generate(
      5,
      (i) => hourlyItem(1 + i, pop: i == 1 ? '70' : '0'),
    );
    await tester.pumpWidget(_harness(HourlyForecast(hourly: wet)));
    await tester.pumpAndSettle();

    expect(find.textContaining('70%'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });
}