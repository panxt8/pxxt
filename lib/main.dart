import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_baidu_mapapi_map/flutter_baidu_mapapi_map.dart';
import 'package:provider/provider.dart';

import 'app/app.dart';
import 'core/location/baidu_location_service.dart';
import 'core/network/app_dio.dart';
import 'core/storage/app_storage.dart';
import 'features/auth/auth_controller.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();

  final storage = AppStorage();
  await storage.init();
  final dio = await AppDio.create(storage);
  await BMFAndroidVersion.initAndroidVersion().timeout(
    const Duration(seconds: 2),
    onTimeout: () {},
  );

  runApp(
    MultiProvider(
      providers: [
        Provider<AppStorage>.value(value: storage),
        Provider<AppDio>.value(value: dio),
        ChangeNotifierProvider<AuthController>(
          create: (_) =>
              AuthController(storage: storage, dio: dio)..restoreSession(),
        ),
      ],
      child: const PxxtApp(),
    ),
  );

  unawaited(BaiduLocationService.instance.initialize());
}
