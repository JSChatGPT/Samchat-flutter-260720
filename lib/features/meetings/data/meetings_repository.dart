import 'package:dio/dio.dart';

import '../../../core/api/api_exception.dart';
import '../../../core/api/endpoints.dart';
import '../../../core/utils/json_utils.dart';
import '../../../models/meeting.dart';

class MeetingsRepository {
  MeetingsRepository(this._dio);

  final Dio _dio;

  Future<List<Meeting>> getMeetings() async {
    try {
      final res = await _dio.get(Endpoints.meetings);
      final raw = res.data is List ? res.data : res.data['meetings'];
      return asList(raw, (e) => Meeting.fromJson(asMap(e)));
    } on DioException catch (e) {
      throw ApiException.fromDioError(e);
    }
  }

  Future<Meeting> createMeeting({
    required String title,
    String? description,
    required DateTime scheduledAt,
    required int durationMinutes,
    required MeetingCallType callType,
    required List<String> inviteeIds,
  }) async {
    try {
      final res = await _dio.post(Endpoints.meetings, data: {
        'title': title,
        if (description != null && description.isNotEmpty) 'description': description,
        'scheduled_at': scheduledAt.toUtc().toIso8601String(),
        'duration_minutes': durationMinutes,
        'call_type': callType == MeetingCallType.audio ? 'audio' : 'video',
        'invitee_ids': inviteeIds,
      });
      return Meeting.fromJson(asMap(res.data['meeting']));
    } on DioException catch (e) {
      throw ApiException.fromDioError(e);
    }
  }

  Future<void> respond(String meetingId, {required bool accept}) async {
    try {
      await _dio.post(Endpoints.meetingRespond(meetingId), data: {
        'status': accept ? 'accepted' : 'declined',
      });
    } on DioException catch (e) {
      throw ApiException.fromDioError(e);
    }
  }

  /// Bookkeeping only (marks `started_at`) — actually starting the call goes
  /// through the normal outgoing-call flow (RouteNames.outgoingCall with the
  /// meeting's chatId), exactly like any other group call, so there's only
  /// one place in the app that creates a Call and rings participants.
  Future<void> start(String meetingId) async {
    try {
      await _dio.post(Endpoints.meetingStart(meetingId));
    } on DioException catch (e) {
      throw ApiException.fromDioError(e);
    }
  }

  /// Fetched via the authenticated Dio client (not a bare URL launch) since
  /// the endpoint sits behind auth:sanctum and a calendar app/browser opening
  /// a raw URL can't send the Bearer token header.
  Future<List<int>> downloadIcs(String meetingId) async {
    try {
      final res = await _dio.get<List<int>>(
        Endpoints.meetingIcs(meetingId),
        options: Options(responseType: ResponseType.bytes),
      );
      return res.data ?? const [];
    } on DioException catch (e) {
      throw ApiException.fromDioError(e);
    }
  }
}
