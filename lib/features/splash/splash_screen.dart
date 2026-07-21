import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

class SplashScreen extends StatelessWidget {
  const SplashScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    // No AppBar on this screen to auto-derive status bar icon color from —
    // override the app-wide light-icon default back to dark since the
    // background here is light.
    return AnnotatedRegion<SystemUiOverlayStyle>(
      value: SystemUiOverlayStyle.dark,
      child: Scaffold(
        backgroundColor: scheme.surface,
        body: SafeArea(
          child: SizedBox(
            width: double.infinity,
            child: Column(
            children: [
              const Spacer(),
              Image.asset(
                'assets/images/samchat_logo.png',
                width: 120,
                height: 120,
              ),
              const SizedBox(height: 20),
              Text('SamChat', style: Theme.of(context).textTheme.headlineSmall),
              const SizedBox(height: 24),
              SizedBox(
                width: 28,
                height: 28,
                child: CircularProgressIndicator(
                  strokeWidth: 2.5,
                  color: scheme.primary,
                ),
              ),
              const Spacer(),
              Text('Powered By', style: Theme.of(context).textTheme.bodySmall?.copyWith(color: Colors.grey[600])),
              const SizedBox(height: 8),
              Image.asset(
                'assets/images/sampay_logo.png',
                height: 36,
              ),
              const SizedBox(height: 24),
            ],
          ),
        ),
      ),
    ),
    );
  }
}
