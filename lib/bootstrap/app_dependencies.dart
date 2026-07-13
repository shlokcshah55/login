import 'package:login/services/google_place_service.dart';
import 'package:login/services/startup_cache/startup_cache_coordinator.dart';
import 'package:login/supabase/service.dart';

class AppDependencies {
  final SupabaseService supabaseService;
  final GooglePlacesService googlePlacesService;
  final StartupCacheCoordinator startupCacheCoordinator;

  AppDependencies({
    required this.supabaseService,
    required this.googlePlacesService,
    required this.startupCacheCoordinator,
  });
}
