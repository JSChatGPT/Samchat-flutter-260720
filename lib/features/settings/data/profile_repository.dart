import 'package:dio/dio.dart';

import '../../../core/api/api_exception.dart';
import '../../../core/api/endpoints.dart';
import '../../../core/api/multipart_helper.dart';
import '../../../core/utils/json_utils.dart';
import '../../../models/user.dart';

class ProfileRepository {
  ProfileRepository(this._dio);

  final Dio _dio;

  Future<AppUser> updateProfile({
    String? firstName,
    String? middleName,
    String? lastName,
    String? email,
    String? username,
    String? aboutStatus,
    String? photoPath,
  }) async {
    try {
      final data = await MultipartHelper.build(
        fields: {
          'first_name': ?firstName,
          'middle_name': ?middleName,
          'last_name': ?lastName,
          'email': ?email,
          'username': ?username,
          'about_status': ?aboutStatus,
        },
        files: photoPath != null ? {'photo': photoPath} : const {},
      );
      final res = await _dio.post(Endpoints.updateProfile, data: data);
      return AppUser.fromJson(asMap(res.data['user']));
    } on DioException catch (e) {
      throw ApiException.fromDioError(e);
    }
  }

  Future<({String privacy, List<String> list})> getPrivacy() async {
    try {
      final res = await _dio.get(Endpoints.privacy);
      return (
        privacy: asString(res.data['status_privacy'], fallback: 'everyone'),
        list: asList(res.data['status_privacy_list'], (e) => e.toString()),
      );
    } on DioException catch (e) {
      throw ApiException.fromDioError(e);
    }
  }

  Future<void> setPrivacy({required String privacy, List<String>? list}) async {
    try {
      await _dio.post(Endpoints.privacy, data: {
        'status_privacy': privacy,
        'status_privacy_list': ?list,
      });
    } on DioException catch (e) {
      throw ApiException.fromDioError(e);
    }
  }

  Future<List<AppUser>> getBlockedUsers() async {
    try {
      final res = await _dio.get(Endpoints.blockedUsers);
      final raw = res.data is List ? res.data : res.data['users'];
      return asList(raw, (e) => AppUser.fromJson(asMap(e)));
    } on DioException catch (e) {
      throw ApiException.fromDioError(e);
    }
  }

  Future<void> block(String userId) async {
    try {
      await _dio.post(Endpoints.block(userId));
    } on DioException catch (e) {
      throw ApiException.fromDioError(e);
    }
  }

  Future<void> unblock(String userId) async {
    try {
      await _dio.delete(Endpoints.block(userId));
    } on DioException catch (e) {
      throw ApiException.fromDioError(e);
    }
  }

  /// Also carries `has_unviewed_status`, used to ring a user's avatar on
  /// their profile/contact-info surface the same way the Status tab does.
  Future<bool> hasUnviewedStatus(String userId) async {
    try {
      final res = await _dio.get(Endpoints.onlineStatus(userId));
      return asBool(res.data['has_unviewed_status']);
    } on DioException catch (e) {
      throw ApiException.fromDioError(e);
    }
  }
}
