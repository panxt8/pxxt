import 'package:dio/dio.dart';

import '../../core/network/app_urls.dart';

class AuthRepository {
  AuthRepository(this._dio);

  final Dio _dio;

  Future<Response<dynamic>> login({
    required String username,
    required String password,
  }) {
    return _dio.get<dynamic>(AppUrls.login(username, password));
  }
}
