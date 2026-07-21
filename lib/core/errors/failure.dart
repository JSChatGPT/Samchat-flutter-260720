/// Typed failure surfaced to the UI layer, translated from ApiException/other
/// exceptions so screens never need to know about Dio.
class Failure {
  const Failure(this.message, {this.fieldErrors, this.statusCode});

  final String message;
  final Map<String, List<String>>? fieldErrors;
  final int? statusCode;

  bool get isValidation => fieldErrors != null && fieldErrors!.isNotEmpty;

  String? firstFieldError(String field) => fieldErrors?[field]?.firstOrNull;

  @override
  String toString() => message;
}
