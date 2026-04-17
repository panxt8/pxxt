import 'dart:math' as math;

class CoordTransform {
  static ({double latitude, double longitude}) wgs84ToGcj02(
    double latitude,
    double longitude,
  ) {
    if (_outOfChina(latitude, longitude)) {
      return (latitude: latitude, longitude: longitude);
    }
    const a = 6378245.0;
    const ee = 0.00669342162296594323;
    final dLat = _transformLat(longitude - 105.0, latitude - 35.0);
    final dLon = _transformLon(longitude - 105.0, latitude - 35.0);
    final radLat = latitude / 180.0 * math.pi;
    var magic = math.sin(radLat);
    magic = 1 - ee * magic * magic;
    final sqrtMagic = math.sqrt(magic);
    final mgLat = latitude + (dLat * 180.0) / ((a * (1 - ee)) / (magic * sqrtMagic) * math.pi);
    final mgLon = longitude + (dLon * 180.0) / (a / sqrtMagic * math.cos(radLat) * math.pi);
    return (latitude: mgLat, longitude: mgLon);
  }

  static ({double latitude, double longitude}) gcj02ToBd09(
    double latitude,
    double longitude,
  ) {
    final z = math.sqrt(longitude * longitude + latitude * latitude) + 0.00002 * math.sin(latitude * math.pi * 3000.0 / 180.0);
    final theta = math.atan2(latitude, longitude) + 0.000003 * math.cos(longitude * math.pi * 3000.0 / 180.0);
    final bdLon = z * math.cos(theta) + 0.0065;
    final bdLat = z * math.sin(theta) + 0.006;
    return (latitude: bdLat, longitude: bdLon);
  }

  static ({double latitude, double longitude}) bd09ToGcj02(
    double latitude,
    double longitude,
  ) {
    final x = longitude - 0.0065;
    final y = latitude - 0.006;
    final z = math.sqrt(x * x + y * y) - 0.00002 * math.sin(y * math.pi * 3000.0 / 180.0);
    final theta = math.atan2(y, x) - 0.000003 * math.cos(x * math.pi * 3000.0 / 180.0);
    final gcjLon = z * math.cos(theta);
    final gcjLat = z * math.sin(theta);
    return (latitude: gcjLat, longitude: gcjLon);
  }

  static ({double latitude, double longitude}) wgs84ToBd09(
    double latitude,
    double longitude,
  ) {
    final gcj = wgs84ToGcj02(latitude, longitude);
    return gcj02ToBd09(gcj.latitude, gcj.longitude);
  }

  static bool _outOfChina(double latitude, double longitude) {
    return longitude < 72.004 || longitude > 137.8347 || latitude < 0.8293 || latitude > 55.8271;
  }

  static double _transformLat(double x, double y) {
    var ret = -100.0 + 2.0 * x + 3.0 * y + 0.2 * y * y + 0.1 * x * y + 0.2 * math.sqrt(x.abs());
    ret += (20.0 * math.sin(6.0 * x * math.pi) + 20.0 * math.sin(2.0 * x * math.pi)) * 2.0 / 3.0;
    ret += (20.0 * math.sin(y * math.pi) + 40.0 * math.sin(y / 3.0 * math.pi)) * 2.0 / 3.0;
    ret += (160.0 * math.sin(y / 12.0 * math.pi) + 320 * math.sin(y * math.pi / 30.0)) * 2.0 / 3.0;
    return ret;
  }

  static double _transformLon(double x, double y) {
    var ret = 300.0 + x + 2.0 * y + 0.1 * x * x + 0.1 * x * y + 0.1 * math.sqrt(x.abs());
    ret += (20.0 * math.sin(6.0 * x * math.pi) + 20.0 * math.sin(2.0 * x * math.pi)) * 2.0 / 3.0;
    ret += (20.0 * math.sin(x * math.pi) + 40.0 * math.sin(x / 3.0 * math.pi)) * 2.0 / 3.0;
    ret += (150.0 * math.sin(x / 12.0 * math.pi) + 300.0 * math.sin(x / 30.0 * math.pi)) * 2.0 / 3.0;
    return ret;
  }
}
