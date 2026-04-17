import 'dart:convert';
import 'package:flutter/foundation.dart';
import '../../core/constants/app_keys.dart';
import '../../core/models/course.dart';
import '../../core/network/app_dio.dart';
import '../../core/storage/app_storage.dart';
import 'home_repository.dart';

class HomeController extends ChangeNotifier {
  HomeController({required AppDio dio, required AppStorage storage})
    : _repository = HomeRepository(dio.client),
      _storage = storage;

  final HomeRepository _repository;
  final AppStorage _storage;

  bool loading = false;
  String? error;
  String username = '';
  List<Course> courses = const [];

  Future<void> load() async {
    loading = true;
    error = null;
    notifyListeners();
    try {
      await Future.wait([loadCourses(), loadUserInfo()]);
    } catch (_) {
      error = '首页加载失败';
    } finally {
      loading = false;
      notifyListeners();
    }
  }

  Future<void> loadCourses() async {
    try {
      final response = await _repository.loadCourses();
      final data = _asMap(response.data);
      final parsed = _parseCourses(data);
      courses = parsed;
      await _storage.setString(AppKeys.homeCoursesCache, jsonEncode(data));
    } catch (_) {
      final cache = _storage.getString(AppKeys.homeCoursesCache);
      if (cache != null && cache.isNotEmpty) {
        courses = _parseCourses(jsonDecode(cache) as Map<String, dynamic>);
      } else {
        rethrow;
      }
    }
  }

  Future<void> loadUserInfo() async {
    try {
      final response = await _repository.loadUserInfo();
      username = _parseUsername(response.data.toString());
    } catch (_) {
      username = '';
    }
  }

  static Map<String, dynamic> _asMap(dynamic data) {
    if (data is Map<String, dynamic>) return data;
    return jsonDecode(data.toString()) as Map<String, dynamic>;
  }

  static List<Course> _parseCourses(Map<String, dynamic> json) {
    final list = json['channelList'];
    if (list is! List) return const [];
    final courses = <Course>[];
    for (final raw in list) {
      if (raw is! Map) continue;
      final cataName = raw['cataName']?.toString() ?? '';
      if (cataName != '课程') continue;
      final content = raw['content'];
      final contentMap = content is Map
          ? Map<String, dynamic>.from(content)
          : <String, dynamic>{};
      final data = contentMap['course'];
      final dataMap = data is Map
          ? Map<String, dynamic>.from(data)
          : <String, dynamic>{};
      final items = dataMap['data'];
      if (items is! List || items.isEmpty || items.first is! Map) continue;
      final first = Map<String, dynamic>.from(items.first as Map);
      courses.add(
        Course(
          courseId: first['id']?.toString() ?? '',
          classId: raw['key']?.toString() ?? '',
          cpi: raw['cpi']?.toString() ?? '',
          title: first['name']?.toString() ?? '-',
          teacher: first['teacherfactor']?.toString() ?? '-',
        ),
      );
    }
    return courses;
  }

  static String _parseUsername(String html) {
    final match = RegExp(
      r'<[^>]*class="user-con"[^>]*>(.*?)</',
    ).firstMatch(html);
    if (match == null) return '';
    return match.group(1)?.replaceAll(RegExp(r'<[^>]+>'), '').trim() ?? '';
  }
}
