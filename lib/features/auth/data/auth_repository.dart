import 'package:dio/dio.dart';

import '../../../core/api/api_exception.dart';
import '../../../core/api/endpoints.dart';
import '../../../core/utils/json_utils.dart';
import '../../../models/user.dart';

class AuthRepository {
  AuthRepository(this._dio);

  final Dio _dio;

  Future<AppUser> register({
    required String firstName,
    String? middleName,
    required String lastName,
    required String username,
    required String phoneNumber,
    String? email,
  }) async {
    try {
      final res = await _dio.post(Endpoints.register, data: {
        'first_name': firstName,
        if (middleName != null && middleName.isNotEmpty) 'middle_name': middleName,
        'last_name': lastName,
        'username': username,
        'phone_number': phoneNumber,
        if (email != null && email.isNotEmpty) 'email': email,
      });
      return AppUser.fromJson(asMap(res.data['user']));
    } on DioException catch (e) {
      throw ApiException.fromDioError(e);
    }
  }

  Future<void> requestOtp(String phoneNumber) async {
    try {
      await _dio.post(Endpoints.requestOtp, data: {'phone_number': phoneNumber});
    } on DioException catch (e) {
      throw ApiException.fromDioError(e);
    }
  }

  Future<({AppUser user, String token})> verifyOtp({
    required String phoneNumber,
    required String otp,
  }) async {
    try {
      final res = await _dio.post(Endpoints.verifyOtp, data: {
        'phone_number': phoneNumber,
        'otp': otp,
      });
      final user = AppUser.fromJson(asMap(res.data['user']));
      final token = asString(res.data['token']);
      return (user: user, token: token);
    } on DioException catch (e) {
      throw ApiException.fromDioError(e);
    }
  }

  Future<void> logout() async {
    try {
      await _dio.post(Endpoints.logout);
    } on DioException catch (e) {
      throw ApiException.fromDioError(e);
    }
  }

  Future<AppUser> me() async {
    try {
      final res = await _dio.get(Endpoints.me);
      return AppUser.fromJson(asMap(res.data['user'] ?? res.data));
    } on DioException catch (e) {
      throw ApiException.fromDioError(e);
    }
  }
}
