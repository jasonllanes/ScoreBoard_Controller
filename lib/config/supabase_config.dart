import 'package:flutter_dotenv/flutter_dotenv.dart';

/// Reads Supabase project config from the bundled .env file (see
/// pubspec.yaml assets and main.dart's dotenv.load() call) instead of
/// hardcoding it — mirrors the import.meta.env.VITE_* pattern from the
/// Vite/JS side of this project.
abstract final class SupabaseConfig {
  static String get url => dotenv.get('SUPABASE_URL');
  static String get anonKey => dotenv.get('SUPABASE_PUBLISHABLE_KEY');
}
