import 'package:flutter/material.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:liquid_glass_widgets/liquid_glass_widgets.dart';
import 'package:permission_handler/permission_handler.dart';
import '../app_localizations.dart';
import '../providers/city_provider.dart';
import '../providers/weather_provider.dart';
import '../providers/settings_provider.dart';
import '../core/constants/app_constants.dart';
import '../core/theme/aurora_background.dart';
import '../services/notification_service.dart';
import 'weather/weather_screen.dart';
import 'ai_assistant/ai_assistant_screen.dart';
import 'settings/settings_screen.dart';

/// 主屏幕，应用的根页面
class MainScreen extends ConsumerStatefulWidget {
  const MainScreen({super.key});

  @override
  ConsumerState<MainScreen> createState() => _MainScreenState();
}

/// 主屏幕状态
class _MainScreenState extends ConsumerState<MainScreen> {
  /// 是否已初始化
  bool _hasInitialized = false;

  /// 当前选中的导航索引
  int _currentIndex = 0;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _initApp();
    });
  }

  /// 初始化应用
  Future<void> _initApp() async {
    if (_hasInitialized) return;
    _hasInitialized = true;

    final isFirstRun = await notificationServiceProvider.isFirstRun();

    if (isFirstRun) {
      await _requestPermissionsOnFirstRun();
      await notificationServiceProvider.markFirstRunCompleted();
    }

    await _initLocation();
  }

  /// 首次运行时请求权限
  Future<void> _requestPermissionsOnFirstRun() async {
    final hasLocationPermission = await ref
        .read(locationInitProvider.notifier)
        .requestLocationPermission();
    if (!mounted) return;

    if (!hasLocationPermission) {
      _showPermissionDialog(
        context.tr('定位权限'),
        context.tr('极光天气需要定位权限来获取您当前位置的天气信息。请在设置中授予定位权限。'),
      );
    }

    final hasNotificationPermission = await notificationServiceProvider
        .requestNotificationPermission();
    if (!mounted) return;

    if (!hasNotificationPermission) {
      _showPermissionDialog(
        context.tr('通知权限'),
        context.tr('极光天气需要通知权限来推送天气预警信息。请在设置中授予通知权限。'),
      );
    }

    await notificationServiceProvider.markNotificationPermissionRequested();
  }

  /// 显示权限请求对话框
  ///
  /// [title] 对话框标题
  /// [message] 对话框内容
  void _showPermissionDialog(String title, String message) {
    if (!mounted) return;

    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text(context.tr(title)),
        content: Text(context.tr(message)),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: Text(context.tr('稍后设置')),
          ),
          TextButton(
            onPressed: () {
              Navigator.pop(ctx);
              openAppSettings();
            },
            child: Text(context.tr('去设置')),
          ),
        ],
      ),
    );
  }

  /// 初始化位置
  /// 天气加载由 ref.listen(locationInitProvider) 统一处理，避免重复加载
  Future<void> _initLocation() async {
    await ref.read(locationInitProvider.notifier).requestLocationPermission();
    await ref.read(locationInitProvider.notifier).initLocation();
  }

  /// 根据新的精度级别刷新位置
  ///
  /// [accuracyLevel] 位置精度级别
  Future<void> _refreshLocationWithNewAccuracy(
    LocationAccuracyLevel accuracyLevel,
  ) async {
    final defaultCity = ref.read(defaultCityProvider);
    if (defaultCity == null) return;

    final locationService = ref.read(locationServiceProvider);
    try {
      final newLocation = await locationService.getLocationFromCoords(
        defaultCity.lat,
        defaultCity.lon,
        accuracyLevel: accuracyLevel,
      );

      await ref
          .read(cityManagerProvider.notifier)
          .updateDefaultCity(newLocation);
      await ref.read(weatherProvider.notifier).loadWeather(newLocation);
    } catch (e) {
      debugPrint('刷新位置失败: $e');
    }
  }

  /// 获取屏幕列表
  ///
  /// [showAIAssistant] 是否显示天气助手
  ///
  /// 返回屏幕列表
  List<Widget> _getScreens(bool showAIAssistant) {
    return [
      const WeatherScreen(),
      if (showAIAssistant) const AIAssistantScreen(),
      const SettingsScreen(),
    ];
  }

  /// 获取导航标签列表
  ///
  /// [showAIAssistant] 是否显示天气助手
  ///
  /// 返回 Liquid Glass 导航标签列表
  List<GlassTab> _getTabs(BuildContext context, bool showAIAssistant) {
    return [
      GlassTab(icon: Icon(LucideIcons.cloud), label: context.tr('天气')),
      if (showAIAssistant)
        GlassTab(icon: Icon(LucideIcons.brain), label: context.tr('天气助手')),
      GlassTab(icon: Icon(LucideIcons.settings), label: context.tr('设置')),
    ];
  }

  @override
  Widget build(BuildContext context) {
    final appSettings = ref.watch(settingsProvider);
    final weatherState = ref.watch(weatherProvider);
    final showAI = appSettings.showAIAssistant;
    final screens = _getScreens(showAI);
    final tabs = _getTabs(context, showAI);
    final weatherData = weatherState.weatherData;
    final weatherCode = weatherData != null
        ? (int.tryParse(weatherData.current.icon) ?? 100)
        : null;

    // 监听位置初始化状态
    ref.listen(locationInitProvider, (previous, next) {
      if (next.isInitialized) {
        final defaultCity = ref.read(defaultCityProvider);
        if (defaultCity != null) {
          ref.read(weatherProvider.notifier).loadWeather(defaultCity);
        }
      }
    });

    // 监听默认城市变化
    ref.listen(defaultCityProvider, (previous, next) {
      if (next != null) {
        ref.read(weatherProvider.notifier).loadWeather(next);
      }
    });

    // 监听设置变化
    ref.listen(settingsProvider, (previous, next) {
      if (previous == null) return;

      if (previous.locationAccuracyLevel != next.locationAccuracyLevel) {
        _refreshLocationWithNewAccuracy(next.locationAccuracyLevel);
      }

      if (previous.showAIAssistant != next.showAIAssistant) {
        setState(() {
          final targetScreens = _getScreens(next.showAIAssistant);
          if (_currentIndex >= targetScreens.length) {
            _currentIndex = targetScreens.length - 1;
          }
        });
      }

      if (previous.androidLiveUpdateNotificationEnabled !=
          next.androidLiveUpdateNotificationEnabled) {
        ref
            .read(weatherProvider.notifier)
            .syncAndroidLiveUpdateNotificationWithSettings(
              scene: 'settings_changed',
            );
      }

      if (previous.appLanguage != next.appLanguage) {
        final defaultCity = ref.read(defaultCityProvider);
        if (defaultCity != null) {
          WidgetsBinding.instance.addPostFrameCallback((_) {
            if (!mounted) return;
            ref.read(weatherProvider.notifier).loadWeather(defaultCity);
          });
        }
      }
    });

    final background =
        weatherCode != null && appSettings.auroraBackgroundEnabled
        ? AuroraBackground(
            weatherCode: weatherCode,
            child: const SizedBox.expand(),
          )
        : ColoredBox(color: Theme.of(context).colorScheme.surface);

    final glassEnabled = appSettings.liquidGlassEnabled;

    final scaffold = Scaffold(
      // 悬浮玻璃底栏覆盖在页面内容之上（原生 iOS 风格），滚动内容
      // 通过自己的底部内边距让最后一项能滚到底栏上方。
      // 关闭玻璃后恢复成 Material 默认底栏，此时内容不再延伸到
      // 底栏后方，和改版前的行为一致。
      extendBody: glassEnabled,
      // 页面级玻璃层会把共享层的玻璃形状统一绘制，IndexedStack 只画
      // 选中页也拦不住未选中页里的玻璃控件（例如助手页的发送按钮会
      // 浮到天气页上）。隔离后每个玻璃控件都使用自己页面子树内的独立
      // 层，未选中页的玻璃就不会再被绘制出来。
      body: glassEnabled
          ? GlassIsolationScope(
              isolated: true,
              child: IndexedStack(index: _currentIndex, children: screens),
            )
          : IndexedStack(index: _currentIndex, children: screens),
      bottomNavigationBar: glassEnabled
          ? _buildFloatingTabBar(context, tabs)
          : _buildMaterialTabBar(context, tabs),
    );

    if (glassEnabled) {
      return GlassPage(background: background, child: scaffold);
    }

    // 关闭液态玻璃时不再使用 GlassPage，直接把背景铺在页面后方，
    // 避免插件做任何背景采样或着色器渲染，性能弱的平台更流畅。
    return Stack(
      fit: StackFit.expand,
      children: [background, scaffold],
    );
  }

  /// 构建悬浮玻璃底栏。
  Widget _buildFloatingTabBar(BuildContext context, List<GlassTab> tabs) {
    return SafeArea(
      top: false,
      minimum: const EdgeInsets.fromLTRB(
        kFloatingTabBarHorizontalMargin,
        0,
        kFloatingTabBarHorizontalMargin,
        12,
      ),
      child: Center(
        heightFactor: 1,
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: kFloatingTabBarMaxWidth),
          child: GlassTabBar.bottom(
            tabs: tabs,
            selectedIndex: _currentIndex,
            horizontalPadding: 0,
            verticalPadding: 0,
            barHeight: kFloatingTabBarHeight,
            barBorderRadius: 30,
            onTabSelected: _onTabSelected,
          ),
        ),
      ),
    );
  }

  /// 关闭 Liquid Glass 后恢复成改版前的 Material 默认底栏。
  ///
  /// 顶部保留一条细分隔线，样式与 Liquid Glass 改版前一致。
  Widget _buildMaterialTabBar(BuildContext context, List<GlassTab> tabs) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        Container(
          height: 0.5,
          color: Theme.of(
            context,
          ).colorScheme.outlineVariant.withValues(alpha: 0.3),
        ),
        NavigationBar(
          selectedIndex: _currentIndex,
          onDestinationSelected: _onTabSelected,
          destinations: [
            for (final tab in tabs)
              NavigationDestination(
                icon: tab.icon ?? const SizedBox.shrink(),
                selectedIcon: tab.activeIcon,
                label: tab.label ?? '',
              ),
          ],
        ),
      ],
    );
  }

  void _onTabSelected(int index) {
    setState(() {
      _currentIndex = index;
    });
  }
}
