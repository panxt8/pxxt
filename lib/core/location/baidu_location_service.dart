import 'dart:async';
import 'dart:io';

import 'package:flutter_baidu_mapapi_base/flutter_baidu_mapapi_base.dart';
import 'package:flutter_bmflocation/flutter_bmflocation.dart';
import 'package:permission_handler/permission_handler.dart';

class BaiduLocationPoint {
  const BaiduLocationPoint({
    required this.latitude,
    required this.longitude,
    this.radius,
    this.address,
    this.networkLocationType,
    this.locType,
  });

  final double latitude;
  final double longitude;
  final double? radius;
  final String? address;
  final String? networkLocationType;
  final int? locType;
}

class BaiduLocationService {
  BaiduLocationService._();

  static final BaiduLocationService instance = BaiduLocationService._();

  final LocationFlutterPlugin _plugin = LocationFlutterPlugin();
  bool _initialized = false;
  Future<void>? _initializing;
  BaiduLocationPoint? _lastPoint;
  DateTime? _lastPointAt;

  Future<void> initialize() async {
    if (_initialized) {
      return;
    }
    if (_initializing != null) {
      return _initializing;
    }
    _initializing = _doInitialize().whenComplete(() {
      _initializing = null;
    });
    return _initializing;
  }

  Future<void> _doInitialize() async {
    if (Platform.isAndroid) {
      // Android privacy and SDK initialization must run before Flutter plugin
      // registration, so they live in PxxtApplication.
      _initialized = true;
      return;
    }
    BMFMapSDK.setAgreePrivacy(true);
    await _plugin
        .setAgreePrivacy(true)
        .timeout(const Duration(seconds: 4), onTimeout: () => false);
    _initialized = true;
  }

  Future<BaiduLocationPoint> locateOnce({
    Duration timeout = const Duration(seconds: 20),
    Duration maxCacheAge = const Duration(seconds: 20),
  }) async {
    final cachedPoint = _lastPoint;
    final cachedAt = _lastPointAt;
    if (cachedPoint != null &&
        cachedAt != null &&
        DateTime.now().difference(cachedAt) <= maxCacheAge) {
      return cachedPoint;
    }

    await _ensureLocationPermission();
    await initialize();

    final first = await _locateOnceWithMode(
      mode: BMFLocationMode.batterySaving,
      timeout: timeout,
    );
    if (first != null) {
      _cachePoint(first);
      return first;
    }

    final second = await _locateOnceWithMode(
      mode: BMFLocationMode.hightAccuracy,
      timeout: timeout,
    );
    if (second != null) {
      _cachePoint(second);
      return second;
    }
    throw StateError('百度定位失败，请重试');
  }

  void _cachePoint(BaiduLocationPoint point) {
    _lastPoint = point;
    _lastPointAt = DateTime.now();
  }

  Future<void> _ensureLocationPermission() async {
    if (!Platform.isAndroid && !Platform.isIOS) return;
    final current = await Permission.locationWhenInUse.status;
    if (current.isGranted) return;

    final requested = await Permission.locationWhenInUse.request();
    if (requested.isGranted) return;

    throw StateError('定位权限未授予');
  }

  Future<BaiduLocationPoint?> _locateOnceWithMode({
    required BMFLocationMode mode,
    required Duration timeout,
  }) async {
    final androidOptions = BaiduLocationAndroidOption(
      coorType: 'bd09ll',
      coordType: BMFLocationCoordType.bd09ll,
      locationMode: mode,
      locationPurpose: BMFLocationPurpose.signIn,
      openGps: true,
      isNeedAddress: true,
      isNeedLocationDescribe: true,
      isNeedLocationPoiList: false,
      isNeedAltitude: false,
      scanspan: 0,
    );
    final iosOptions = BaiduLocationIOSOption(
      coordType: BMFLocationCoordType.bd09ll,
      BMKLocationCoordinateType: 'BMKLocationCoordinateTypeBMK09LL',
      desiredAccuracy: BMFDesiredAccuracy.best,
      locationTimeout: timeout.inSeconds,
      reGeocodeTimeout: timeout.inSeconds,
    );
    await _plugin
        .prepareLoc(androidOptions.getMap(), iosOptions.getMap())
        .timeout(
          const Duration(seconds: 5),
          onTimeout: () {
            throw TimeoutException('prepareLoc timeout');
          },
        );

    final completer = Completer<BaiduLocationPoint?>();
    _plugin.singleLocationCallback(
      callback: (result) async {
        if (completer.isCompleted) return;
        final lat = result.latitude;
        final lon = result.longitude;
        if (lat == null || lon == null || lat == 0 || lon == 0) {
          completer.complete(null);
          await _plugin.stopLocation();
          return;
        }
        completer.complete(
          BaiduLocationPoint(
            latitude: lat,
            longitude: lon,
            radius: result.radius,
            address: result.address,
            networkLocationType: result.networkLocationType,
            locType: result.locType,
          ),
        );
        await _plugin.stopLocation();
      },
    );

    final started = await _plugin.startLocation().timeout(
      const Duration(seconds: 5),
      onTimeout: () {
        return false;
      },
    );
    if (!started) {
      return null;
    }
    try {
      return await completer.future.timeout(timeout);
    } on TimeoutException {
      await _plugin.stopLocation();
      return null;
    }
  }
}
