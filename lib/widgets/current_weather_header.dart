import 'package:flutter/material.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';

import '../app_localizations.dart';
import '../core/constants/app_constants.dart';
import '../core/theme/app_theme.dart';
import '../models/weather_models.dart';
import 'glass/aurora_glass_icon_button.dart';

/// 首页当前天气概览头部。
///
/// 展示城市名、当前大字温度、天气状态与最高/最低/体感温度。
/// 前景对比度统一走 [BuildContext.weatherContrastColorsFor]，
/// 与设置页 / AI 助手页保持一致，避免手写逻辑重复。
class CurrentWeatherHeader extends StatelessWidget {
  /// 完整天气数据
  final WeatherData weather;

  /// 当前城市，可能为空（未定位成功）
  final Location? location;

  /// 温度单位（celsius / fahrenheit）
  final String temperatureUnit;

  /// 是否启用天气驱动背景
  final bool auroraBackgroundEnabled;

  /// 右上角定位/导航按钮点击回调
  final VoidCallback onLocatePressed;

  const CurrentWeatherHeader({
    super.key,
    required this.weather,
    required this.location,
    required this.temperatureUnit,
    required this.auroraBackgroundEnabled,
    required this.onLocatePressed,
  });

  @override
  Widget build(BuildContext context) {
    final contrast = context.weatherContrastColorsFor(
      int.tryParse(weather.current.icon) ?? 100,
      useWeatherContrast: auroraBackgroundEnabled,
    );
    final todayDaily = weather.daily.isNotEmpty ? weather.daily.first : null;

    return Padding(
      padding: EdgeInsets.only(
        left: 24,
        right: 24,
        bottom: 0,
        top: 12 + MediaQuery.of(context).padding.top,
      ),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          _buildCityNameRow(context, contrast),
          const SizedBox(height: 8),
          _buildCurrentTemperature(context, contrast),
          const SizedBox(height: 8),
          _buildWeatherStatusRow(context, todayDaily, contrast),
          const SizedBox(height: 16),
          _buildTempSummary(context, todayDaily, contrast),
        ],
      ),
    );
  }

  /// 城市名称 + 右上角定位按钮。
  ///
  /// 标题左右各留出按钮宽度并做省略号截断，
  /// 超长城市名不再与「导航」按钮重叠。
  Widget _buildCityNameRow(
    BuildContext context,
    WeatherContrastColors contrast,
  ) {
    return SizedBox(
      height: 48,
      child: Stack(
        alignment: Alignment.center,
        clipBehavior: Clip.none,
        children: [
          Positioned(
            left: 56,
            right: 56,
            child: Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                if (location?.isLocated == true) ...[
                  Icon(LucideIcons.mapPin, size: 20, color: contrast.accent),
                  const SizedBox(width: 4),
                ],
                Flexible(
                  child: Text(
                    location?.name ?? context.tr('未知位置'),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    textAlign: TextAlign.center,
                    style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                      color: contrast.foreground,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                ),
              ],
            ),
          ),
          Positioned(
            right: 0,
            child: AuroraGlassIconButton(
              icon: LucideIcons.navigation,
              color: contrast.muted,
              size: 44,
              iconSize: 22,
              preferOwnLayer: true,
              onPressed: onLocatePressed,
              tooltip: context.tr('导航'),
            ),
          ),
        ],
      ),
    );
  }

  /// 当前温度大字 + 单位
  Widget _buildCurrentTemperature(
    BuildContext context,
    WeatherContrastColors contrast,
  ) {
    final useF = temperatureUnit == 'fahrenheit';

    return Row(
      mainAxisAlignment: MainAxisAlignment.center,
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          WeatherCode.convertTemperature(
            weather.current.temp,
            toFahrenheit: useF,
          ),
          style: Theme.of(context).textTheme.displayLarge?.copyWith(
            color: contrast.foreground,
            fontWeight: FontWeight.w300,
            fontSize: 72,
          ),
        ),
        Padding(
          padding: const EdgeInsets.only(top: 12),
          child: Text(
            useF ? '°F' : '°',
            style: Theme.of(
              context,
            ).textTheme.displayMedium?.copyWith(color: contrast.foreground),
          ),
        ),
      ],
    );
  }

  /// 天气状态：图标 + 文字描述
  Widget _buildWeatherStatusRow(
    BuildContext context,
    DailyWeather? todayDaily,
    WeatherContrastColors contrast,
  ) {
    final isNight = WeatherCode.isNightTimeFromObsTime(
      weather.current.obsTime,
      sunrise: todayDaily?.sunrise,
      sunset: todayDaily?.sunset,
    );
    final code = int.tryParse(weather.current.icon) ?? 100;

    return Row(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        Icon(
          WeatherCode.getWeatherIcon(code, isNight: isNight),
          size: 32,
          color: contrast.accent,
        ),
        const SizedBox(width: 8),
        Text(
          context.tr(weather.current.text),
          style: Theme.of(
            context,
          ).textTheme.titleLarge?.copyWith(color: contrast.foreground),
        ),
      ],
    );
  }

  /// 最高 / 最低 / 体感温度。
  ///
  /// 用 Wrap 包裹：窄屏或大字体下自动换行，不再横向溢出。
  Widget _buildTempSummary(
    BuildContext context,
    DailyWeather? todayDaily,
    WeatherContrastColors contrast,
  ) {
    final useF = temperatureUnit == 'fahrenheit';
    final unit = useF ? '°F' : '°';

    String format(String value) {
      return '${WeatherCode.convertTemperature(value, toFahrenheit: useF)}$unit';
    }

    return Wrap(
      spacing: 0,
      runSpacing: 8,
      alignment: WrapAlignment.center,
      crossAxisAlignment: WrapCrossAlignment.center,
      children: [
        if (todayDaily != null) ...[
          _TempBlock(
            label: context.tr('最高'),
            value: format(todayDaily.tempMax),
            contrast: contrast,
          ),
          _TempDivider(contrast: contrast),
          _TempBlock(
            label: context.tr('最低'),
            value: format(todayDaily.tempMin),
            contrast: contrast,
          ),
          _TempDivider(contrast: contrast),
        ],
        _TempBlock(
          label: context.tr('体感'),
          value: format(weather.current.feelsLike),
          contrast: contrast,
        ),
      ],
    );
  }
}

/// 温度信息项：标签 + 值
class _TempBlock extends StatelessWidget {
  final String label;
  final String value;
  final WeatherContrastColors contrast;

  const _TempBlock({
    required this.label,
    required this.value,
    required this.contrast,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        Text(
          label,
          style: Theme.of(context).textTheme.bodySmall?.copyWith(
            color: contrast.muted,
          ),
        ),
        Text(
          value,
          style: Theme.of(context).textTheme.titleMedium?.copyWith(
            color: contrast.foreground,
            fontWeight: FontWeight.w500,
          ),
        ),
      ],
    );
  }
}

/// 温度项之间的细分隔线
class _TempDivider extends StatelessWidget {
  final WeatherContrastColors contrast;

  const _TempDivider({required this.contrast});

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 1,
      height: 16,
      margin: const EdgeInsets.symmetric(horizontal: 16),
      color: contrast.divider,
    );
  }
}