import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:path_provider/path_provider.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// Holds app-level settings (currently just the uploaded logo) that persist
/// across restarts. The picked image is copied into the app's own documents
/// directory rather than kept at its original (often temporary/cache) path,
/// since that path isn't guaranteed to survive an app restart.
class AppSettingsService extends ChangeNotifier {
  static const String _logoPathPrefKey = 'app_logo_path';

  String? _logoPath;
  String? get logoPath => _logoPath;
  bool get hasLogo => _logoPath != null && File(_logoPath!).existsSync();

  Future<void> load() async {
    final prefs = await SharedPreferences.getInstance();
    final stored = prefs.getString(_logoPathPrefKey);
    if (stored != null && File(stored).existsSync()) {
      _logoPath = stored;
      notifyListeners();
    }
  }

  Future<void> setLogo(File sourceFile) async {
    final docsDir = await getApplicationDocumentsDirectory();
    final ext = sourceFile.path.split('.').last;
    final savedPath = '${docsDir.path}/app_logo.$ext';

    // Overwriting a previous logo saved under a different extension would
    // otherwise leave both files on disk.
    if (_logoPath != null && _logoPath != savedPath) {
      final old = File(_logoPath!);
      if (await old.exists()) await old.delete();
    }

    await sourceFile.copy(savedPath);
    _logoPath = savedPath;
    notifyListeners();

    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_logoPathPrefKey, savedPath);
  }

  Future<void> clearLogo() async {
    if (_logoPath != null) {
      final file = File(_logoPath!);
      if (await file.exists()) await file.delete();
    }
    _logoPath = null;
    notifyListeners();

    final prefs = await SharedPreferences.getInstance();
    await prefs.remove(_logoPathPrefKey);
  }
}
