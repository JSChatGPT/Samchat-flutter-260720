import 'package:dio/dio.dart';

import '../errors/failure.dart';

/// Wraps a failed API call. The backend is inconsistent about error key
/// naming across controllers (`{"error": "..."}` vs `{"message": "..."}`),
/// and validation errors use Laravel's `{"message", "errors": {field: [...]}}`
/// shape — this normalizes all three into one type.
class ApiException implements Exception {
  ApiException({
    required this.message,
    this.statusCode,
    this.fieldErrors,
  });

  final String message;
  final int? statusCode;
  final Map<String, List<String>>? fieldErrors;

  factory ApiException.fromDioError(DioException e) {
    final response = e.response;
    if (response == null) {
      if (e.type == DioExceptionType.connectionTimeout ||
          e.type == DioExceptionType.receiveTimeout ||
          e.type == DioExceptionType.sendTimeout) {
        return ApiException(message: 'Connection timed out. Check your internet.');
      }
      if (e.type == DioExceptionType.connectionError) {
        return ApiException(message: 'No internet connection.');
      }
      return ApiException(message: e.message ?? 'Something went wrong.');
    }

    final data = response.data;
    final statusCode = response.statusCode;
    Map<String, List<String>>? fieldErrors;
    String? message;

    if (data is Map) {
      final errorsRaw = data['errors'];
      if (errorsRaw is Map) {
        fieldErrors = errorsRaw.map(
          (k, v) => MapEntry(k.toString(), (v as List).map((e) => e.toString()).toList()),
        );
      }
      // Sampay proxy endpoints (validate-recipient, request-chat, approve, reject)
      // wrap the upstream reason as {"error": "<generic>", "details": {"message": "<specific>"}}.
      // Prefer the specific reason when present.
      final details = data['details'];
      final detailsMessage = details is Map ? details['message'] : null;
      message = (detailsMessage ?? data['message'] ?? data['error'])?.toString();
    }

    message ??= switch (statusCode) {
      401 => 'Session expired. Please log in again.',
      403 => 'You are not allowed to do that.',
      404 => 'Not found.',
      422 => 'Please check the highlighted fields.',
      503 => 'Service temporarily unavailable.',
      _ => 'Something went wrong (${statusCode ?? 'unknown'}).',
    };

    return ApiException(message: message, statusCode: statusCode, fieldErrors: fieldErrors);
  }

  Failure toFailure() => Failure(message, fieldErrors: fieldErrors, statusCode: statusCode);

  bool get isUnauthorized => statusCode == 401;
  bool get isForbidden => statusCode == 403;

  @override
  String toString() => message;
}
