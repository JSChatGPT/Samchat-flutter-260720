import 'package:flutter/material.dart';

/// Small rounded unread-count pill (same visual style as the chat-list
/// unread badge), reused for the email accounts list and Email tab.
/// Renders nothing when [count] is 0. Caps the displayed number at "99+".
class CountBadge extends StatelessWidget {
  const CountBadge({super.key, required this.count, this.color, this.textColor});

  final int count;
  final Color? color;
  final Color? textColor;

  @override
  Widget build(BuildContext context) {
    if (count <= 0) return const SizedBox.shrink();
    final scheme = Theme.of(context).colorScheme;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 3),
      decoration: BoxDecoration(color: color ?? scheme.primary, borderRadius: BorderRadius.circular(12)),
      child: Text(
        count > 99 ? '99+' : '$count',
        style: TextStyle(color: textColor ?? scheme.onPrimary, fontSize: 11, fontWeight: FontWeight.w700),
      ),
    );
  }
}
