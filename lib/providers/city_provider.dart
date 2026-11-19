import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:geolocator/geolocator.dart';

import '../app_localizations.dart';
import '../models/weather_models.dart';
import '../providers/settings_provider.dart';
import '../services/location_service.dart';
import 'city_repository.dart';

@immutable
class CityState {
  final List<Location> cities;
  final bool isLoaded;
  final String? errorMessage;

  const CityState({
    required this.cities,
    required this.isLoaded,
    required this.errorMessage,
  });

  Location? get defaultCity {
    if (cities.isEmpty) {
      return null;
    }
    try {
      return cities.firstWhere((city) => city.isDefault);
    } catch (_) {
      return cities.first;
    }
  }
}

class CityController extends StateNotifier<List<Location>> {
  final CityRepository _repository;
  late final Future<void> _ready;

  bool _isLoaded = false;
  String? _errorMessage;

  CityController(this._repository) : super(const <Location>[]) {
    _ready = _load();
  }

  bool get isLoaded => _isLoaded;
  bool get hasCities => state.isNotEmpty;
  int get cityCount => state.length;
  String? get errorMessage => _errorMessage;

  CityState get snapshot => CityState(
        cities: state,
        isLoaded: _isLoaded,
        errorMessage: _errorMessage,
      );

  Location? get defaultCity {
    if (state.isEmpty) {
      return null;
    }
    try {
      return state.firstWhere((city) => city.isDefault);
    } catch (_) {
      return state.first;
    }
  }

  Future<void> _load() async {
    try {
      final store = await _repository.loadStore();
      state = store.cities;
      _errorMessage = null;
    } catch (e) {
      _errorMessage = e.toString();
      state = const <Location>[];
    } finally {
      _isLoaded = true;
    }
  }

  Future<void> _ensureReady() async {
    await _ready;
  }

  /// 等待城市列表从本地存储加载完成
  Future<void> ensureLoaded() => _ready;

  bool _isSameCity(Location a, Location b) {
    return a.id == b.id ||
        (a.name == b.name && a.adm2 == b.adm2 && a.adm1 == b.adm1);
  }

  Future<void> _commit(List<Location> nextCities, {String? defaultCityId}) async {
    final normalized = _repository.normalize(
      CityStoreSnapshot(cities: nextCities, defaultCityId: defaultCityId),
    );
    await _repository.saveStore(normalized);
    state = normalized.cities;
    _errorMessage = null;
  }

  Future<void> addCity(Location location) async {
    await _ensureReady();
    final exists = state.any((city) => _isSameCity(city, location));
    if (exists) {
      return;
    }

    final next = [
      ...state,
      location.copyWith(
        isDefault: state.isEmpty,
        sortOrder: state.length,
        isLocated: false,
      ),
    ];
    await _commit(next, defaultCityId: defaultCity?.id ?? location.id);
  }

  Future<void> addCityAndSetDefault(Location location, {bool isLocated = false}) async {
    await _ensureReady();

    final existingIndex = state.indexWhere((city) => _isSameCity(city, location));
    final next = <Location>[...state];

    if (existingIndex >= 0) {
      final existing = next[existingIndex];
      next[existingIndex] = location.copyWith(
        sortOrder: existing.sortOrder,
        isDefault: true,
        isLocated: isLocated || existing.isLocated,
      );
    } else {
      next.add(
        location.copyWith(
          isDefault: true,
          isLocated: isLocated,
          sortOrder: next.length,
        ),
      );
    }

    if (isLocated) {
      for (var i = 0; i < next.length; i++) {
        if (next[i].id != location.id) {
          next[i] = next[i].copyWith(isLocated: false);
        }
      }
    }

    await _commit(next, defaultCityId: location.id);
  }

  Future<void> removeCity(String cityId) async {
    await _ensureReady();
    final existingIndex = state.indexWhere((city) => city.id == cityId);
    if (existingIndex < 0) {
      return;
    }

    final removed = state[existingIndex];
    final next = state.where((city) => city.id != cityId).toList();

    if (next.isEmpty) {
      await _commit(const <Location>[], defaultCityId: null);
      return;
    }

    String? nextDefaultId = defaultCity?.id;
    if (removed.isDefault || nextDefaultId == cityId) {
      final located = next.where((city) => city.isLocated).toList();
      nextDefaultId = located.isNotEmpty ? located.first.id : next.first.id;
    }

    await _commit(next, defaultCityId: nextDefaultId);
  }

  Future<void> setDefaultCity(String cityId) async {
    await _ensureReady();
    if (!state.any((city) => city.id == cityId)) {
      return;
    }
    await _commit(state, defaultCityId: cityId);
  }

  Future<void> updateDefaultCity(Location newLocation) async {
    await _ensureReady();
    final currentDefault = defaultCity;
    if (currentDefault == null) {
      await addCityAndSetDefault(newLocation, isLocated: newLocation.isLocated);
      return;
    }

    final next = <Location>[...state];
    final defaultIndex = next.indexWhere((city) => city.id == currentDefault.id);
    if (defaultIndex < 0) {
      await addCityAndSetDefault(newLocation, isLocated: newLocation.isLocated);
      return;
    }

    next[defaultIndex] = newLocation.copyWith(
      isDefault: true,
      sortOrder: next[defaultIndex].sortOrder,
      isLocated: next[defaultIndex].isLocated || newLocation.isLocated,
    );

    if (next[defaultIndex].isLocated) {
      for (var i = 0; i < next.length; i++) {
        if (i != defaultIndex) {
          next[i] = next[i].copyWith(isLocated: false);
        }
      }
    }

    await _commit(next, defaultCityId: next[defaultIndex].id);
  }

  Future<void> reorderCities(int oldIndex, int newIndex) async {
    await _ensureReady();
    if (state.isEmpty) {
      return;
    }
    if (oldIndex < 0 ||
        oldIndex >= state.length ||
        newIndex < 0 ||
        newIndex >= state.length) {
      return;
    }

    final next = [...state];
    if (newIndex > oldIndex) {
      newIndex -= 1;
    }
    final moved = next.removeAt(oldIndex);
    next.insert(newIndex, moved);

    await _commit(next, defaultCityId: defaultCity?.id);
  }
}

final cityRepositoryProvider = Provider<CityRepository>((ref) => CityRepository());

final cityManagerProvider = StateNotifierProvider<CityController, List<Location>>((ref) {
  final repository = ref.watch(cityRepositoryProvider);
  return CityController(repository);
});

final cityStateProvider = Provider<CityState>((ref) {
  ref.watch(cityManagerProvider);
  return ref.watch(cityManagerProvider.notifier).snapshot;
});

final defaultCityProvider = Provider<Location?>((ref) {
  final cities = ref.watch(cityManagerProvider);
  if (cities.isEmpty) {
    return null;
  }
  try {
    return cities.firstWhere((city) => city.isDefault);
  } catch (_) {
    return cities.first;
  }
});

@immutable
class LocationInitState {
  final bool isInitialized;
  final bool isLocating;
  final Location? currentLocation;
  final String? error;

  const LocationInitState({
    this.isInitialized = false,
    this.isLocating = false,
    this.currentLocation,
    this.error,
  });

  LocationInitState copyWith({
    bool? isInitialized,
    bool? isLocating,
    Location? currentLocation,
    String? error,
    bool clearError = false,
  }) {
    return LocationInitState(
      isInitialized: isInitialized ?? this.isInitialized,
      isLocating: isLocating ?? this.isLocating,
      currentLocation: currentLocation ?? this.currentLocation,
      error: clearError ? null : (error ?? this.error),
    );
  }
}

class LocationInitNotifier extends StateNotifier<LocationInitState> {
  final Ref _ref;

  /// 防止定位流程重复执行
  bool _isLocating = false;

  LocationInitNotifier(this._ref) : super(const LocationInitState());

  /// 初始化当前位置
  ///
  /// 先用系统缓存位置快速出结果，再请求一次新鲜位置；
  /// 反向地理编码在后台补齐城市名称，不阻塞天气加载。
  Future<void> initLocation({bool force = false}) async {
    if (_isLocating) return;
    if (state.isInitialized && !force) return;

    _isLocating = true;
    state = state.copyWith(
      isInitialized: false,
      isLocating: true,
      clearError: true,
    );

    try {
      final locationService = _ref.read(locationServiceProvider);
      final hasPermission = await locationService.checkAndRequestPermission();
      if (!hasPermission) {
        state = LocationInitState(
          isInitialized: true,
          error: AppLocalizations.tr('无法获取位置，请检查权限设置'),
        );
        return;
      }

      // 1. 系统缓存位置通常立即可用，先让界面出结果
      final cached = await locationService.getLastKnownPosition();
      if (cached != null) {
        await _applyPosition(cached);
      }

      // 2. 再请求新鲜位置，失败时保留缓存位置
      final fresh = await locationService.getCurrentPosition();
      if (fresh != null) {
        await _applyPosition(fresh);
      }

      if (state.currentLocation == null) {
        state = LocationInitState(
          isInitialized: true,
          error: AppLocalizations.tr('暂时无法获取当前位置，请重试或手动选择城市'),
        );
      } else {
        state = state.copyWith(
          isInitialized: true,
          isLocating: false,
          clearError: true,
        );
      }
    } catch (e) {
      state = LocationInitState(
        isInitialized: true,
        error: e.toString(),
      );
    } finally {
      _isLocating = false;
      if (state.isLocating) {
        state = state.copyWith(isLocating: false);
      }
    }
  }

  /// 应用一次定位结果
  ///
  /// [position]: 定位坐标
  Future<void> _applyPosition(Position position) async {
    final locationService = _ref.read(locationServiceProvider);
    final appSettings = _ref.read(settingsProvider);
    final cityController = _ref.read(cityManagerProvider.notifier);
    final currentDefaultCity = _ref.read(defaultCityProvider);

    final provisional = _buildProvisionalLocation(position);
    var shouldSwitch = currentDefaultCity == null;
    if (currentDefaultCity != null) {
      final latDiff = (position.latitude - currentDefaultCity.lat).abs();
      final lonDiff = (position.longitude - currentDefaultCity.lon).abs();
      shouldSwitch = latDiff > 0.01 || lonDiff > 0.01;
    }

    if (shouldSwitch) {
      // 当前默认城市就是上一次的定位城市时原地替换，避免累积多个“当前位置”
      if (currentDefaultCity != null && currentDefaultCity.isLocated) {
        await cityController.updateDefaultCity(provisional);
      } else {
        // 先用坐标占位，天气请求不必等待反向地理编码
        await cityController.addCityAndSetDefault(provisional, isLocated: true);
      }
    }

    state = state.copyWith(currentLocation: provisional, clearError: true);

    try {
      final resolved = await locationService
          .getLocationFromCoords(
            position.latitude,
            position.longitude,
            accuracyLevel: appSettings.locationAccuracyLevel,
          )
          .timeout(const Duration(seconds: 5));

      state = state.copyWith(currentLocation: resolved, clearError: true);
      if (shouldSwitch) {
        final latestDefault = _ref.read(defaultCityProvider);
        if (latestDefault != null && latestDefault.isLocated) {
          await cityController.updateDefaultCity(resolved);
        } else {
          await cityController.addCityAndSetDefault(resolved, isLocated: true);
        }
      }
    } catch (e) {
      // 反向地理编码失败不影响天气展示，保留坐标占位名称
      debugPrint('[LocationInit] 反向地理编码失败: $e');
    }
  }

  /// 用坐标构造占位城市，id 与反向地理编码结果保持一致
  ///
  /// [position]: 定位坐标
  Location _buildProvisionalLocation(Position position) {
    return Location(
      id:
          '${position.longitude.toStringAsFixed(4)},${position.latitude.toStringAsFixed(4)}',
      name: AppLocalizations.tr('当前位置'),
      adm1: '',
      adm2: '',
      country: AppLocalizations.tr('中国'),
      lat: position.latitude,
      lon: position.longitude,
      tz: 'Asia/Shanghai',
      utcOffset: '+08:00',
      isDefault: true,
      sortOrder: 0,
      isLocated: true,
    );
  }

  Future<bool> requestLocationPermission({bool forceRequest = true}) async {
    try {
      final locationService = _ref.read(locationServiceProvider);
      return await locationService.checkAndRequestPermission(
        forceRequest: forceRequest,
      );
    } catch (_) {
      return false;
    }
  }
}

final locationServiceProvider = Provider<LocationService>((ref) => LocationService());

final locationInitProvider = StateNotifierProvider<LocationInitNotifier, LocationInitState>(
  (ref) => LocationInitNotifier(ref),
);
