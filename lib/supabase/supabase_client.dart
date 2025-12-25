import 'package:flutter/foundation.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';

/// Singleton class that provides a centralized access point to the Supabase client.
class SupabaseClientManager {
  static final SupabaseClientManager _instance = SupabaseClientManager._internal();
  
  factory SupabaseClientManager() => _instance;
  
  SupabaseClientManager._internal();

  /// Initializes the Supabase client with the provided URL and key.
  /// Should be called in the main() function before runApp().
  /// Includes OAuth deep link handling configuration.
  static Future<void> initialize() async {
    try {
      final supabaseUrl = dotenv.env['SUPABASE_URL'];
      final supabaseKey = dotenv.env['SUPABASE_ANON_KEY'];

      if (supabaseUrl == null || supabaseKey == null) {
        throw Exception('Supabase URL or API key not found in .env file');
      }

      await Supabase.initialize(
        url: supabaseUrl,
        anonKey: supabaseKey,
        debug: kDebugMode,
        // OAuth configuration for deep link handling
        // The SDK automatically handles deep links matching the redirect URL pattern
        // Used with URL scheme: com.srishlok.pinit://login-callback/
        authOptions: const FlutterAuthClientOptions(
          authFlowType: AuthFlowType.pkce,
        ),
      );

      // Listen for auth errors and handle token refresh failures
      Supabase.instance.client.auth.onAuthStateChange.listen(
        (data) {
          final event = data.event;
          if (event == AuthChangeEvent.tokenRefreshed) {
            if (kDebugMode) {
              print('Token refreshed successfully');
            }
          }
        },
        onError: (error) {
          // Catch token refresh failures at the SDK level
          if (kDebugMode) {
            print('SupabaseClientManager: Auth error: $error');

            // Check for specific oauth_client_id error
            if (error.toString().contains('oauth_client_id') ||
                error.toString().contains('AuthRetryableFetchException')) {
              print('SupabaseClientManager: Token refresh failed - session may be invalid');
            }
          }
        },
      );

      if (kDebugMode) {
        print('Supabase client initialized successfully with OAuth support');
      }
    } catch (e) {
      if (kDebugMode) {
        print('Error initializing Supabase client: $e');
      }
      rethrow;
    }
  }

  /// Returns the Supabase client instance.
  SupabaseClient get client => Supabase.instance.client;
  
  /// Returns the current authenticated user, or null if not authenticated.
  User? get currentUser => client.auth.currentUser;
  
  /// Returns true if a user is currently authenticated.
  bool get isAuthenticated => currentUser != null;
  
  /// Returns the current session, or null if not authenticated.
  Session? get currentSession => client.auth.currentSession;
}