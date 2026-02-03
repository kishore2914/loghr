import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:flutter/services.dart';
import 'package:flutter/foundation.dart';

class SupabaseConfig {
  static SupabaseClient? _client;

  static Future<void> initialize() async {
    await dotenv.load(fileName: '.env');
    
    final supabaseUrl = dotenv.env['SUPABASE_URL'];
    final supabaseAnonKey = dotenv.env['SUPABASE_ANON_KEY'];

    if (supabaseUrl == null || supabaseAnonKey == null) {
      throw Exception('Missing Supabase credentials in .env file');
    }

    await Supabase.initialize(
      url: supabaseUrl,
      anonKey: supabaseAnonKey,
      // Suppress app_links error on Windows
      debug: false,
      // Configure auth options for better timeout handling
      authOptions: const FlutterAuthClientOptions(
        // Auto refresh token is enabled by default
        // Token refresh will retry automatically on failure
        autoRefreshToken: true,
      ),
    );

    _client = Supabase.instance.client;
    
    // Suppress the app_links MissingPluginException on Windows
    // This is a known issue with deep linking on desktop platforms
    FlutterError.onError = (FlutterErrorDetails details) {
      // Ignore app_links errors on Windows
      if (details.exception is MissingPluginException &&
          details.exception.toString().contains('app_links')) {
        return;
      }
      
      // Ignore Supabase token refresh timeout errors (non-critical background operation)
      final errorStr = details.exception.toString();
      if (errorStr.contains('AuthRetryableFetchException') ||
          errorStr.contains('SocketException') ||
          (errorStr.contains('semaphore timeout') && errorStr.contains('token'))) {
        // These are non-critical - token refresh will retry automatically
        // Log for debugging but don't show to user
        if (kDebugMode) {
          print('⚠️ Supabase token refresh timeout (non-critical): ${details.exception}');
        }
        return;
      }
      
      // Let other errors through
      FlutterError.presentError(details);
    };
  }

  static SupabaseClient get client {
    if (_client == null) {
      throw Exception('Supabase client not initialized. Call initialize() first.');
    }
    return _client!;
  }
}

// Convenience getter for accessing Supabase client
SupabaseClient get supabase => SupabaseConfig.client;
