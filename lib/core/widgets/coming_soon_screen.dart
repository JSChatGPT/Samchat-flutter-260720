import 'package:flutter/material.dart';

/// Placeholder body for a tab whose real screen hasn't landed yet in the
/// build sequence — swapped out feature-by-feature.
class ComingSoonScreen extends StatelessWidget {
  const ComingSoonScreen({super.key, required this.title, required this.icon});

  final String title;
  final IconData icon;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Scaffold(
      appBar: AppBar(title: Text(title)),
      body: Center(
        child: Icon(icon, size: 48, color: scheme.outlineVariant),
      ),
    );
  }
}
