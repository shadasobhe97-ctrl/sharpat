import 'package:flutter/foundation.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../config/supabase_config.dart';

/// Centralized service to manage Supabase initialization and client access.
class SupabaseService {
  SupabaseService._();

  static bool _isInitialized = false;

  /// Initialize Supabase client.
  /// If credentials have not been configured yet, logs a warning without crashing the app.
  static Future<void> init() async {
    if (_isInitialized) return;

    if (!SupabaseConfig.isConfigured) {
      debugPrint(
        '⚠️ [SupabaseService] لم يتم تهيئة مفاتيح Supabase بعد.\n'
        'يرجى إضافة SUPABASE_URL و SUPABASE_ANON_KEY في ملف supabase_config.dart\n'
        'أو تمريرها عبر --dart-define عند التشغيل.',
      );
      return;
    }

    try {
      await Supabase.initialize(
        url: SupabaseConfig.supabaseUrl,
        // ignore: deprecated_member_use
        anonKey: SupabaseConfig.supabaseAnonKey,
        debug: kDebugMode,
      );
      _isInitialized = true;
      debugPrint('✅ [SupabaseService] تم الاتصال بـ Supabase بنجاح.');
    } catch (e, stack) {
      debugPrint('❌ [SupabaseService] خطأ أثناء الاتصال بـ Supabase: $e');
      debugPrint(stack.toString());
    }
  }

  /// Whether Supabase has been successfully initialized
  static bool get isInitialized => _isInitialized;

  /// Safe accessor for SupabaseClient. Returns null if not initialized yet.
  static SupabaseClient? get clientOrNull =>
      _isInitialized ? Supabase.instance.client : null;

  /// Direct client accessor (throws StateError if accessed before valid initialization)
  static SupabaseClient get client {
    if (!_isInitialized) {
      throw StateError(
        'Supabase client is not initialized. Please verify your Supabase credentials in supabase_config.dart.',
      );
    }
    return Supabase.instance.client;
  }
}
