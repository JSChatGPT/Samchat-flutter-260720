import 'package:shared_preferences/shared_preferences.dart';

/// Non-sensitive local flags: theme mode, onboarding completion, etc.
class LocalPrefsService {
  LocalPrefsService(this._prefs);

  final SharedPreferences _prefs;

  static Future<LocalPrefsService> create() async {
    final prefs = await SharedPreferences.getInstance();
    return LocalPrefsService(prefs);
  }

  static const _themeModeKey = 'theme_mode';
  static const _contactsSyncedKey = 'contacts_synced';
  static const _lastTabKey = 'last_tab_index';
  static const _appLockEnabledKey = 'app_lock_enabled';
  static const _appLockTimeoutKey = 'app_lock_timeout';

  String? get themeMode => _prefs.getString(_themeModeKey);
  Future<void> setThemeMode(String mode) => _prefs.setString(_themeModeKey, mode);

  // Device-level security preference, deliberately not cleared on logout
  // (see clear()) — same reasoning as themeMode: it belongs to the install,
  // not the session.
  bool get appLockEnabled => _prefs.getBool(_appLockEnabledKey) ?? false;
  Future<void> setAppLockEnabled(bool v) => _prefs.setBool(_appLockEnabledKey, v);

  String? get appLockTimeout => _prefs.getString(_appLockTimeoutKey);
  Future<void> setAppLockTimeout(String value) => _prefs.setString(_appLockTimeoutKey, value);

  bool get contactsSynced => _prefs.getBool(_contactsSyncedKey) ?? false;
  Future<void> setContactsSynced(bool v) => _prefs.setBool(_contactsSyncedKey, v);

  int get lastTabIndex => _prefs.getInt(_lastTabKey) ?? 0;
  Future<void> setLastTabIndex(int v) => _prefs.setInt(_lastTabKey, v);

  Future<void> clear() async {
    await _prefs.remove(_contactsSyncedKey);
    await _prefs.remove(_lastTabKey);
  }
}
