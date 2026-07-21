import 'package:dio/dio.dart';

import '../../../core/api/api_exception.dart';
import '../../../core/api/endpoints.dart';
import '../../../core/api/multipart_helper.dart';
import '../../../core/utils/json_utils.dart';
import '../../../models/status.dart';
import '../../../models/status_view.dart';

class StatusesRepository {
  StatusesRepository(this._dio);

  final Dio _dio;

  Future<List<StatusGroup>> getStatuses() async {
    try {
      final res = await _dio.get(Endpoints.statuses);
      final raw = res.data is Map ? res.data['statuses'] : res.data;
      return StatusGroup.listFromGroupedJson(raw);
    } on DioException catch (e) {
      throw ApiException.fromDioError(e);
    }
  }

  Future<StatusItem> createStatus({
    required StatusType type,
    String? content,
    String? mediaPath,
    String? backgroundColor,
  }) async {
    try {
      final data = await MultipartHelper.build(
        fields: {
          'type': type.name,
          if (content != null && content.isNotEmpty) 'content': content,
          'background_color': ?backgroundColor,
        },
        files: mediaPath != null ? {'media': mediaPath} : const {},
      );
      final res = await _dio.post(Endpoints.statuses, data: data);
      final json = res.data['status'] ?? res.data;
      return StatusItem.fromJson(asMap(json));
    } on DioException catch (e) {
      throw ApiException.fromDioError(e);
    }
  }

  Future<void> deleteStatus(String id) async {
    try {
      await _dio.delete(Endpoints.deleteStatus(id));
    } on DioException catch (e) {
      throw ApiException.fromDioError(e);
    }
  }

  Future<void> markViewed(String id) async {
    try {
      await _dio.post(Endpoints.viewStatus(id));
    } on DioException catch (e) {
      throw ApiException.fromDioError(e);
    }
  }

  Future<List<StatusView>> getViews(String id) async {
    try {
      final res = await _dio.get(Endpoints.statusViews(id));
      final raw = res.data is List ? res.data : res.data['views'];
      return asList(raw, (e) => StatusView.fromJson(asMap(e)));
    } on DioException catch (e) {
      throw ApiException.fromDioError(e);
    }
  }
}
