import 'package:intl/intl.dart';

/// Chat-oriented date/time formatting (WhatsApp-style "Today"/"Yesterday").
class AppDateUtils {
  AppDateUtils._();

  static String inboxTimestamp(DateTime dt) {
    final now = DateTime.now();
    final local = dt.toLocal();
    final today = DateTime(now.year, now.month, now.day);
    final that = DateTime(local.year, local.month, local.day);
    final diff = today.difference(that).inDays;

    if (diff == 0) return DateFormat.jm().format(local);
    if (diff == 1) return 'Yesterday';
    if (diff < 7) return DateFormat.EEEE().format(local);
    return DateFormat.yMd().format(local);
  }

  static String messageTime(DateTime dt) => DateFormat.jm().format(dt.toLocal());

  static String dateSeparator(DateTime dt) {
    final now = DateTime.now();
    final local = dt.toLocal();
    final today = DateTime(now.year, now.month, now.day);
    final that = DateTime(local.year, local.month, local.day);
    final diff = today.difference(that).inDays;

    if (diff == 0) return 'Today';
    if (diff == 1) return 'Yesterday';
    if (diff < 7) return DateFormat.EEEE().format(local);
    return DateFormat.yMMMd().format(local);
  }

  static bool isSameDay(DateTime a, DateTime b) {
    final la = a.toLocal();
    final lb = b.toLocal();
    return la.year == lb.year && la.month == lb.month && la.day == lb.day;
  }

  static String lastSeen(DateTime? dt) {
    if (dt == null) return 'offline';
    final local = dt.toLocal();
    final now = DateTime.now();
    final diff = now.difference(local);
    if (diff.inMinutes < 2) return 'online';
    if (diff.inMinutes < 60) return 'last seen ${diff.inMinutes}m ago';
    if (isSameDay(local, now)) return 'last seen today at ${DateFormat.jm().format(local)}';
    final yesterday = now.subtract(const Duration(days: 1));
    if (isSameDay(local, yesterday)) {
      return 'last seen yesterday at ${DateFormat.jm().format(local)}';
    }
    return 'last seen ${DateFormat.yMMMd().format(local)}';
  }

  static String durationLabel(int seconds) {
    final d = Duration(seconds: seconds);
    final m = d.inMinutes.remainder(60).toString().padLeft(2, '0');
    final s = d.inSeconds.remainder(60).toString().padLeft(2, '0');
    if (d.inHours > 0) {
      final h = d.inHours.toString();
      return '$h:$m:$s';
    }
    return '$m:$s';
  }
}
