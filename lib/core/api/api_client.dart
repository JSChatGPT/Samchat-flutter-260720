import 'package:dio/dio.dart';

import '../config/app_config.dart';
import '../storage/secure_storage_service.dart';
import 'auth_interceptor.dart';
import 'session_controller.dart';

/// Thin wrapper around a configured [Dio] instance. All repositories take
/// this (or the raw [Dio] via [dio]) rather than constructing their own.
class ApiClient {
  ApiClient({required SecureStorageService storage, required SessionController session}) {
    dio = Dio(
      BaseOptions(
        baseUrl: AppConfig.apiBaseUrl,
        connectTimeout: const Duration(seconds: 20),
        receiveTimeout: const Duration(seconds: 30),
        sendTimeout: const Duration(seconds: 60),
        headers: {'Accept': 'application/json'},
      ),
    );
    dio.interceptors.add(AuthInterceptor(storage, session));
  }

  late final Dio dio;
}
