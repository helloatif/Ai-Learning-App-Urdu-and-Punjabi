import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';

class ThemeProvider extends ChangeNotifier {
  bool _isDarkMode;
  bool _isLoaded = false;
  String _userId = ''; // empty = no specific user, uses generic fallback key

  bool get isDarkMode => _isDarkMode;
  bool get isLoaded => _isLoaded;

  // Constructor accepts initial value from main.dart (pre-loaded for current user)
  ThemeProvider({bool initialDarkMode = false, String userId = ''})
    : _isDarkMode = initialDarkMode,
      _userId = userId {
    _isLoaded = true;
  }

  String get _prefKey =>
      _userId.isNotEmpty ? 'isDarkMode_$_userId' : 'isDarkMode';

  /// Called after a user logs in — loads their personal dark-mode preference.
  Future<void> loadForUser(String uid) async {
    _userId = uid;
    try {
      final prefs = await SharedPreferences.getInstance();
      final savedValue = prefs.getBool('isDarkMode_$uid') ?? false;
      if (savedValue != _isDarkMode) {
        _isDarkMode = savedValue;
        notifyListeners();
      }
      debugPrint('✓ Theme loaded for user $uid: isDarkMode=$_isDarkMode');
    } catch (e) {
      debugPrint('⚠ Failed to load theme for user $uid: $e');
    }
  }

  /// Called when a user logs out — resets to light mode and clears user context.
  Future<void> resetForLogout() async {
    _userId = '';
  }

  Future<void> toggleTheme() async {
    _isDarkMode = !_isDarkMode;
    await _saveThemePreference();
    notifyListeners();
  }

  Future<void> setDarkMode(bool value) async {
    if (_isDarkMode == value) return;
    _isDarkMode = value;
    await _saveThemePreference();
    notifyListeners();
  }

  Future<void> _saveThemePreference() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setBool(_prefKey, _isDarkMode);
      debugPrint('✓ Theme saved (key=$_prefKey): isDarkMode=$_isDarkMode');
    } catch (e) {
      debugPrint('⚠ Failed to save theme preference: $e');
    }
  }
}
