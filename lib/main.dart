import 'dart:async';
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_baidu_mapapi_base/flutter_baidu_mapapi_base.dart';
import 'package:flutter_baidu_mapapi_map/flutter_baidu_mapapi_map.dart';
import 'package:provider/provider.dart';

import 'app/app.dart';
import 'core/location/baidu_location_service.dart';
import 'core/network/app_dio.dart';
import 'core/storage/app_storage.dart';
import 'core/theme/app_theme_controller.dart';
import 'features/auth/auth_controller.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  if (Platform.isIOS) {
    BMFMapSDK.setAgreePrivacy(true);
    BMFMapSDK.setCoordType(BMF_COORD_TYPE.BD09LL);
  }

  final storage = AppStorage();
  await storage.init();
  final dio = await AppDio.create(storage);

  runApp(
    MultiProvider(
      providers: [
        Provider<AppStorage>.value(value: storage),
        Provider<AppDio>.value(value: dio),
        ChangeNotifierProvider<AppThemeController>(
          create: (_) => AppThemeController(storage: storage),
        ),
        ChangeNotifierProvider<AuthController>(
          create: (_) =>
              AuthController(storage: storage, dio: dio)..restoreSession(),
        ),
      ],
      child: const PxxtApp(),
    ),
  );

  unawaited(
    BMFAndroidVersion.initAndroidVersion()
        .timeout(const Duration(seconds: 2), onTimeout: () {})
        .catchError((_) {}),
  );
  unawaited(BaiduLocationService.instance.initialize().catchError((_) {}));
}
