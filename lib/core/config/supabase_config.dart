/// Configuration file for Supabase connection.
/// 
/// Values can be supplied at build/run time via `--dart-define`:
/// ```bash
/// flutter run --dart-define=SUPABASE_URL=https://your-project.supabase.co --dart-define=SUPABASE_ANON_KEY=your-anon-key
/// ```
/// Or by replacing the default placeholders below.
class SupabaseConfig {
  SupabaseConfig._();

  /// Project URL from Supabase Project Settings -> API
  static const String supabaseUrl = String.fromEnvironment(
    'SUPABASE_URL',
    defaultValue: 'https://YOUR_PROJECT_ID.supabase.co',
  );

  /// Anon / Public Key from Supabase Project Settings -> API
  static const String supabaseAnonKey = String.fromEnvironment(
    'SUPABASE_ANON_KEY',
    defaultValue: 'YOUR_SUPABASE_ANON_KEY',
  );

  /// Storage bucket name for product images
  static const String productImagesBucket = 'product-images';

  /// Default temporary reservation duration in minutes
  static const int reservationDurationMinutes = 60;

  /// Check whether credentials have been configured
  static bool get isConfigured {
    return supabaseUrl.isNotEmpty &&
        !supabaseUrl.contains('YOUR_PROJECT_ID') &&
        supabaseAnonKey.isNotEmpty &&
        !supabaseAnonKey.contains('YOUR_SUPABASE_ANON_KEY');
  }
}
