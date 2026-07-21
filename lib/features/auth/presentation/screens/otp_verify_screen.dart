import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/api/api_exception.dart';
import '../../application/auth_notifier.dart';
import '../widgets/otp_input.dart';

class OtpVerifyScreen extends ConsumerStatefulWidget {
  const OtpVerifyScreen({super.key});

  @override
  ConsumerState<OtpVerifyScreen> createState() => _OtpVerifyScreenState();
}

class _OtpVerifyScreenState extends ConsumerState<OtpVerifyScreen> {
  bool _verifying = false;
  String? _error;
  int _cooldown = 0;
  Timer? _timer;

  @override
  void initState() {
    super.initState();
    _startCooldown();
  }

  @override
  void dispose() {
    _timer?.cancel();
    super.dispose();
  }

  void _startCooldown() {
    _cooldown = 30;
    _timer?.cancel();
    _timer = Timer.periodic(const Duration(seconds: 1), (t) {
      if (_cooldown <= 1) {
        t.cancel();
        setState(() => _cooldown = 0);
      } else {
        setState(() => _cooldown--);
      }
    });
  }

  Future<void> _verify(String otp) async {
    setState(() {
      _verifying = true;
      _error = null;
    });
    try {
      await ref.read(authNotifierProvider.notifier).verifyOtp(otp);
      // Router redirect (auth state -> authenticated) takes it from here.
    } on ApiException catch (e) {
      setState(() => _error = e.message);
    } finally {
      if (mounted) setState(() => _verifying = false);
    }
  }

  Future<void> _resend() async {
    final phone = ref.read(authNotifierProvider).pendingPhoneNumber;
    if (phone == null) return;
    try {
      await ref.read(authNotifierProvider.notifier).requestOtp(phone);
      _startCooldown();
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Code resent')));
      }
    } on ApiException catch (e) {
      if (mounted) setState(() => _error = e.message);
    }
  }

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final phone = ref.watch(authNotifierProvider).pendingPhoneNumber ?? '';
    return Scaffold(
      appBar: AppBar(),
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 24),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text('Enter verification code', style: Theme.of(context).textTheme.headlineSmall),
              const SizedBox(height: 8),
              Text(
                'We sent a 6-digit code to $phone',
                style: Theme.of(context).textTheme.bodyMedium,
              ),
              if (kDebugMode) ...[
                const SizedBox(height: 6),
                Text(
                  'Dev backend: OTP is mocked — use 123456',
                  style: TextStyle(color: scheme.secondary, fontSize: 12),
                ),
              ],
              const SizedBox(height: 32),
              if (_verifying)
                const Center(child: CircularProgressIndicator())
              else
                OtpInput(length: 6, onCompleted: _verify),
              if (_error != null) ...[
                const SizedBox(height: 16),
                Text(_error!, style: TextStyle(color: scheme.error)),
              ],
              const SizedBox(height: 24),
              Center(
                child: TextButton(
                  onPressed: _cooldown == 0 ? _resend : null,
                  child: Text(_cooldown == 0 ? 'Resend code' : 'Resend in ${_cooldown}s'),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
