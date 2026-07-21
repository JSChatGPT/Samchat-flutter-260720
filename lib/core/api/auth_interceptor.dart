import 'package:dio/dio.dart';

import '../storage/secure_storage_service.dart';
import 'session_controller.dart';

/// Attaches `Authorization: Bearer {token}` to every request, and on a bare
/// 401 (dead/revoked token) notifies [SessionController] so the app can force
/// a logout. Endpoints that are expected to return other 4xx codes for
/// business reasons (e.g. 403 for a blocked user trying to message) are left
/// alone — this only reacts to 401.
class AuthInterceptor extends Interceptor {
  AuthInterceptor(this._storage, this._session);

  final SecureStorageService _storage;
  final SessionController _session;

  @override
  void onRequest(RequestOptions options, RequestInterceptorHandler handler) async {
    final token = await _storage.readToken();
    if (token != null && token.isNotEmpty) {
      options.headers['Authorization'] = 'Bearer $token';
    }
    options.headers['Accept'] = 'application/json';
    handler.next(options);
  }

  @override
  void onError(DioException err, ErrorInterceptorHandler handler) {
    if (err.response?.statusCode == 401) {
      _session.notifyUnauthorized();
    }
    handler.next(err);
  }
}
