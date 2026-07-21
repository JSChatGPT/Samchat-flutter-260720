import 'package:dio/dio.dart';

import '../../../core/api/api_exception.dart';
import '../../../core/api/endpoints.dart';
import '../../../core/api/multipart_helper.dart';
import '../../../core/crypto/e2ee_service.dart';
import '../../../core/utils/json_utils.dart';
import '../../../models/chat.dart';

class GroupsRepository {
  GroupsRepository(this._dio, this._e2ee);

  final Dio _dio;
  final E2eeService _e2ee;

  Future<Chat> createGroup({required String groupName, required List<String> userIds}) async {
    try {
      final res = await _dio.post(Endpoints.groups, data: {
        'group_name': groupName,
        'user_ids': userIds,
      });
      final json = res.data['chat'] ?? res.data;
      final chat = Chat.fromJson(asMap(json));
      // Awaited so the first message in a brand-new group isn't sent as
      // plaintext (see the identical note on ChatsRepository.createOrGetDirectChat).
      await _e2ee.distributeNewChatKey(chat.id, chat.participants.map((p) => p.userId).toList());
      return chat;
    } on DioException catch (e) {
      throw ApiException.fromDioError(e);
    }
  }

  Future<void> updateGroup(String chatId, {String? groupName, bool? onlyAdminsCanPost}) async {
    try {
      await _dio.put(Endpoints.groupInfo(chatId), data: {
        'group_name': ?groupName,
        'only_admins_can_post': ?onlyAdminsCanPost,
      });
    } on DioException catch (e) {
      throw ApiException.fromDioError(e);
    }
  }

  Future<String?> uploadGroupImage(String chatId, String imagePath) async {
    try {
      final data = await MultipartHelper.build(files: {'group_image': imagePath});
      final res = await _dio.post(Endpoints.groupImage(chatId), data: data);
      return asStringOrNull(res.data['group_image_url'] ?? res.data['group']?['group_image_url']);
    } on DioException catch (e) {
      throw ApiException.fromDioError(e);
    }
  }

  Future<void> leaveGroup(String chatId) async {
    try {
      await _dio.post(Endpoints.leaveGroup(chatId));
    } on DioException catch (e) {
      throw ApiException.fromDioError(e);
    }
  }

  Future<void> addParticipants(String chatId, List<String> userIds) async {
    try {
      await _dio.post(Endpoints.participants(chatId), data: {'user_ids': userIds});
      for (final userId in userIds) {
        await _e2ee.distributeKeyToNewMember(chatId, userId);
      }
    } on DioException catch (e) {
      throw ApiException.fromDioError(e);
    }
  }

  Future<void> setParticipantRole(String chatId, String userId, {required bool isAdmin}) async {
    try {
      await _dio.put(Endpoints.participantRole(chatId, userId), data: {'is_admin': isAdmin});
    } on DioException catch (e) {
      throw ApiException.fromDioError(e);
    }
  }

  Future<void> removeParticipant(String chatId, String userId) async {
    try {
      await _dio.delete(Endpoints.removeParticipant(chatId, userId));
    } on DioException catch (e) {
      throw ApiException.fromDioError(e);
    }
  }
}
