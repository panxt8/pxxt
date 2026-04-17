import 'dart:io';

import 'package:flutter/services.dart';
import 'package:flutter_bmflocation/src/private/bdmap_location_method_id.dart';

class BMFLocationOptionsDispatcher {
  /// 设置定位参数
  Future<bool> setLocationOptions(
      MethodChannel channel, Map androidMap, Map iosMap) async {
    ArgumentError.checkNotNull(androidMap, "androidMap");
    ArgumentError.checkNotNull(iosMap, "iosMap");

    bool result = false;
    try {
      Map map = (await channel.invokeMethod(
          BMFLocationOptionsMethodId.kLocationSetOptions,
          Platform.isAndroid ? androidMap : iosMap) as Map);
      result = map['result'] as bool;
    } on PlatformException catch (e) {
      print(e.toString());
    }
    return result;
  }

  Future<bool> setDisableLocInForeground(
      MethodChannel channel) async {
    bool result = false;
    try {
      Map map = (await channel.invokeMethod(
          BMFLocationOptionsMethodId.kDisableLocInForeground) as Map);
      result = map['result'] as bool;
    } on PlatformException catch (e) {
      print(e.toString());
    }
    return result;
  }

  Future<bool> setEnableLocInForeground(MethodChannel channel, String notifationId,
      String notifationName, String title, String text) async {
    ArgumentError.checkNotNull(title, "title");
    ArgumentError.checkNotNull(text, "text");
    ArgumentError.checkNotNull(text, "notifationId");
    ArgumentError.checkNotNull(text, "notifationName");
    bool result = false;
    try {
      Map notifationMap = {'notifationId': notifationId, 'notifationName': notifationName, 'title': title, 'text': text};
      Map map = (await channel.invokeMethod(
              BMFLocationOptionsMethodId.kEnableLocInForeground, notifationMap)
          as Map);
      result = map['result'] as bool;
    } on PlatformException catch (e) {
      print(e.toString());
    }
    return result;
  }
}
