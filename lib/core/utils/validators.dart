class Validators {
  Validators._();

  static final _usernameReg = RegExp(r'^[a-zA-Z0-9_.]{3,30}$');

  static String? otp(String? value) {
    if (value == null || value.trim().isEmpty) return 'Enter the code';
    if (value.trim().length != 6) return 'Code must be 6 digits';
    return null;
  }

  static String? required(String? value, {String label = 'This field'}) {
    if (value == null || value.trim().isEmpty) return '$label is required';
    return null;
  }

  static String? username(String? value) {
    if (value == null || value.trim().isEmpty) return 'Username is required';
    if (!_usernameReg.hasMatch(value.trim())) {
      return 'Username must be 3-30 chars: letters, numbers, _ or .';
    }
    return null;
  }

  static String? email(String? value) {
    if (value == null || value.trim().isEmpty) return null; // optional
    final ok = RegExp(r'^[^@\s]+@[^@\s]+\.[^@\s]+$').hasMatch(value.trim());
    return ok ? null : 'Enter a valid email';
  }
}
