import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:intl_phone_field/intl_phone_field.dart';

import '../../../../core/api/api_exception.dart';
import '../../../../core/router/route_names.dart';
import '../../../../core/utils/validators.dart';
import '../../../../core/widgets/app_text_field.dart';
import '../../application/auth_notifier.dart';

class RegisterScreen extends ConsumerStatefulWidget {
  const RegisterScreen({super.key, this.initialPhone});

  final String? initialPhone;

  @override
  ConsumerState<RegisterScreen> createState() => _RegisterScreenState();
}

class _RegisterScreenState extends ConsumerState<RegisterScreen> {
  final _formKey = GlobalKey<FormState>();
  final _firstName = TextEditingController();
  final _middleName = TextEditingController();
  final _lastName = TextEditingController();
  final _username = TextEditingController();
  final _email = TextEditingController();
  String _phone = '';

  bool _submitting = false;
  String? _error;
  Map<String, List<String>>? _fieldErrors;

  @override
  void initState() {
    super.initState();
    if (widget.initialPhone != null) _phone = widget.initialPhone!;
  }

  @override
  void dispose() {
    _firstName.dispose();
    _middleName.dispose();
    _lastName.dispose();
    _username.dispose();
    _email.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    if (!_formKey.currentState!.validate()) return;
    setState(() {
      _submitting = true;
      _error = null;
      _fieldErrors = null;
    });
    final phone = _phone;
    try {
      await ref.read(authNotifierProvider.notifier).register(
            firstName: _firstName.text.trim(),
            middleName: _middleName.text.trim(),
            lastName: _lastName.text.trim(),
            username: _username.text.trim(),
            phoneNumber: phone,
            email: _email.text.trim(),
          );
      await ref.read(authNotifierProvider.notifier).requestOtp(phone);
      if (!mounted) return;
      context.pushNamed(RouteNames.otpVerify);
    } on ApiException catch (e) {
      setState(() {
        _error = e.message;
        _fieldErrors = e.fieldErrors;
      });
    } finally {
      if (mounted) setState(() => _submitting = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Scaffold(
      appBar: AppBar(title: const Text('Create account')),
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(24),
          child: Form(
            key: _formKey,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Tell us a bit about yourself',
                  style: Theme.of(context).textTheme.titleMedium,
                ),
                const SizedBox(height: 20),
                AppTextField(
                  controller: _firstName,
                  label: 'First name',
                  validator: (v) => Validators.required(v, label: 'First name'),
                ),
                const SizedBox(height: 14),
                AppTextField(controller: _middleName, label: 'Middle name (optional)'),
                const SizedBox(height: 14),
                AppTextField(
                  controller: _lastName,
                  label: 'Last name',
                  validator: (v) => Validators.required(v, label: 'Last name'),
                ),
                const SizedBox(height: 14),
                AppTextField(
                  controller: _username,
                  label: 'Username',
                  validator: Validators.username,
                  prefixIcon: const Icon(Icons.alternate_email),
                ),
                const SizedBox(height: 14),
                IntlPhoneField(
                  decoration: const InputDecoration(labelText: 'Phone number'),
                  initialCountryCode: widget.initialPhone == null ? 'ZM' : null,
                  initialValue: widget.initialPhone,
                  invalidNumberMessage: 'Enter a valid phone number',
                  onChanged: (phone) => _phone = phone.completeNumber,
                ),
                const SizedBox(height: 14),
                AppTextField(
                  controller: _email,
                  label: 'Email (optional)',
                  keyboardType: TextInputType.emailAddress,
                  validator: Validators.email,
                  prefixIcon: const Icon(Icons.mail_outline),
                ),
                if (_error != null) ...[
                  const SizedBox(height: 14),
                  Text(_error!, style: TextStyle(color: scheme.error)),
                ],
                if (_fieldErrors != null)
                  ..._fieldErrors!.entries.map(
                    (e) => Padding(
                      padding: const EdgeInsets.only(top: 4),
                      child: Text('${e.key}: ${e.value.join(', ')}',
                          style: TextStyle(color: scheme.error, fontSize: 12)),
                    ),
                  ),
                const SizedBox(height: 24),
                ElevatedButton(
                  onPressed: _submitting ? null : _submit,
                  child: _submitting
                      ? const SizedBox(
                          width: 22,
                          height: 22,
                          child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white),
                        )
                      : const Text('Create account'),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
