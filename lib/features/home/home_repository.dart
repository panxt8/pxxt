import 'package:dio/dio.dart';

import '../../core/network/app_urls.dart';

class HomeRepository {
  HomeRepository(this._dio);

  final Dio _dio;

  Future<Response<dynamic>> loadCourses() {
    return _dio.get<dynamic>(AppUrls.allCourses());
  }

  Future<Response<dynamic>> loadUserInfo() {
    return _dio.get<dynamic>(AppUrls.userInfo());
  }
}
