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
      );
      
      if (kDebugMode) {
        print('Supabase client initialized successfully');
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