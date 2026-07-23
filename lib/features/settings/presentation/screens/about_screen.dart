import 'package:flutter/material.dart';

class AboutScreen extends StatelessWidget {
  const AboutScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('About Samchat')),
      body: Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Image.asset('assets/images/samchat_logo.png', width: 88, height: 88),
            const SizedBox(height: 16),
            Text('Samchat', style: Theme.of(context).textTheme.titleLarge),
            const SizedBox(height: 4),
            Text('Version 1.0.0', style: Theme.of(context).textTheme.bodySmall),
            const SizedBox(height: 16),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 32),
              child: Text(
                'Simple. Secure. Fast messaging.',
                textAlign: TextAlign.center,
                style: Theme.of(context).textTheme.bodyMedium,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
