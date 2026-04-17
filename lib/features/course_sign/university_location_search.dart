import 'package:flutter/services.dart';
import 'package:msgpack_dart/msgpack_dart.dart';

class UniversityLocation {
  const UniversityLocation({
    required this.name,
    required this.province,
    required this.city,
    required this.area,
    required this.address,
    required this.latitude,
    required this.longitude,
  });

  final String name;
  final String province;
  final String city;
  final String area;
  final String address;
  final double latitude;
  final double longitude;

  String get fullAddress {
    return [
      province,
      city,
      area,
      address,
    ].map((e) => e.trim()).where((e) => e.isNotEmpty).join(' ');
  }

  static UniversityLocation? fromDynamic(dynamic value) {
    if (value is! Map) return null;
    final map = Map<String, dynamic>.from(value);

    final lat = _toDouble(map['lat']);
    final lng = _toDouble(map['lng']);
    if (lat == null || lng == null) return null;

    return UniversityLocation(
      name: _toText(map['n']),
      province: _toText(map['p']),
      city: _toText(map['c']),
      area: _toText(map['a']),
      address: _toText(map['addr']),
      latitude: lat,
      longitude: lng,
    );
  }

  static String _toText(dynamic value) => value?.toString().trim() ?? '';

  static double? _toDouble(dynamic value) {
    if (value is num) return value.toDouble();
    return double.tryParse(value?.toString() ?? '');
  }
}

class UniversityLocationSearch {
  UniversityLocationSearch({
    this.assetPath = 'assets/data/universities_location.msgpack',
  });

  final String assetPath;
  List<UniversityLocation>? _cache;

  Future<void> ensureLoaded() async {
    if (_cache != null) return;

    final byteData = await rootBundle.load(assetPath);
    final bytes = byteData.buffer.asUint8List(
      byteData.offsetInBytes,
      byteData.lengthInBytes,
    );

    final decoded = deserialize(bytes);
    if (decoded is! List) {
      _cache = const [];
      return;
    }

    final list = <UniversityLocation>[];
    for (final item in decoded) {
      final model = UniversityLocation.fromDynamic(item);
      if (model != null) {
        list.add(model);
      }
    }
    _cache = list;
  }

  List<UniversityLocation> search(String keyword, {int limit = 20}) {
    final source = _cache ?? const <UniversityLocation>[];
    final q = keyword.trim().toLowerCase();
    if (q.isEmpty || source.isEmpty) return const [];

    final scored = <({UniversityLocation item, int score})>[];
    for (final item in source) {
      final score = _score(item, q);
      if (score > 0) {
        scored.add((item: item, score: score));
      }
    }

    scored.sort((a, b) => b.score.compareTo(a.score));
    if (scored.length > limit) {
      return scored.take(limit).map((e) => e.item).toList();
    }
    return scored.map((e) => e.item).toList();
  }

  static int _score(UniversityLocation item, String q) {
    final name = item.name.toLowerCase();
    final city = item.city.toLowerCase();
    final area = item.area.toLowerCase();
    final address = item.fullAddress.toLowerCase();

    var score = 0;
    if (name == q) score += 200;
    if (name.startsWith(q)) score += 120;
    if (name.contains(q)) score += 90;
    if (city == q) score += 80;
    if (city.contains(q)) score += 40;
    if (area.contains(q)) score += 30;
    if (address.contains(q)) score += 20;
    return score;
  }
}
