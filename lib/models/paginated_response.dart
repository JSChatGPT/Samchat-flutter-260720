import '../core/utils/json_utils.dart';

/// Generic wrapper for Laravel-style paginated responses
/// (`data`, `current_page`, `last_page`, `next_page_url`, ...).
class PaginatedResponse<T> {
  const PaginatedResponse({
    required this.items,
    required this.currentPage,
    required this.lastPage,
    required this.hasMore,
  });

  final List<T> items;
  final int currentPage;
  final int lastPage;
  final bool hasMore;

  factory PaginatedResponse.fromJson(
    Map<String, dynamic> json,
    T Function(Map<String, dynamic>) mapper, {
    String dataKey = 'data',
  }) {
    final currentPage = asInt(json['current_page'], fallback: 1);
    final lastPage = asInt(json['last_page'], fallback: 1);
    return PaginatedResponse(
      items: asList(json[dataKey], (e) => mapper(asMap(e))),
      currentPage: currentPage,
      lastPage: lastPage,
      hasMore: currentPage < lastPage,
    );
  }
}
